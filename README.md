# ConnectCall

**Connect with anyone, anywhere.**

ConnectCall is a 1-to-1 audio and video calling app built in Flutter. Two real accounts can sign in, see each other in a live contact list, place audio/video calls, accept or reject, mute/camera-control, and persist history to Firestore.

This is not a UI mockup: signaling uses **Firebase**, media uses **Agora RTC**.

## Features

- Email/password registration and login (Firebase Auth), logout
- Splash routing: Home if signed in, otherwise Login
- Live contacts from Firestore with online/offline dots
- Real-time name search
- 1-to-1 **audio** calls: initiate, ring, accept, reject, end
- Audio controls: mute/unmute, speaker, end
- 1-to-1 **video** calls with remote feed + local PiP
- Video controls: mute, camera on/off, switch camera, end
- Incoming-call screen driven by a Firestore listener (FCM token stored for bonus push)
- Call history: peer, time, audio/video, in/out, duration, missed
- Permissions via `permission_handler` (retry + open Settings)
- Error states: offline, permission denied, busy, reject, failed connect
- Bonus: dark/light/system theme, block user (long-press contact), recent contacts, network quality chip (Good/Fair/Poor)

## Tech stack (and why)

| Layer | Choice | Why |
|---|---|---|
| Framework | Flutter 3.32 / Dart 3.8 (null-safe) | One codebase for Android/iOS, fast UI iteration, strong plugin ecosystem for camera/mic |
| State | **Riverpod** | Call state is async + streaming (Auth, Firestore snapshots, Agora callbacks). Providers rebuild only dependents; `StreamProvider` maps Firestore; `StateNotifier` owns the call state machine |
| Backend | **Firebase Auth + Firestore** | Real accounts, live user list/presence, call signaling without a custom server |
| Push | **FCM** | Stores device tokens; optional Cloud Function can notify when the app is backgrounded |
| Calling | **Agora RTC** | Fastest reliable 1-to-1 path: free tier, mute/speaker/switch-camera APIs, connection and network-quality callbacks |
| Navigation | **go_router** | Auth redirects + bottom-nav `StatefulShellRoute` |
| Permissions | **permission_handler** | Mic before any call, camera before video; denied vs permanently denied |

**Rebuild behavior:** widgets `ref.watch` a provider. When that provider’s value changes, *that* widget rebuilds — not the whole tree. Agora events update `CallController` state; only call screens watching `callControllerProvider` rebuild (timer, mute icon, remote video).

## Architecture

Business logic lives in `services/`. Screens never import `FirebaseAuth`, `FirebaseFirestore`, or Agora APIs except the video view (which needs the engine instance for `AgoraVideoView`).

```
lib/
├── core/           constants, theme, validators, permissions
├── models/         UserModel, CallModel + CallPhase
├── services/       AuthService, UserService, CallingService
├── providers/      Riverpod wiring + CallController
├── screens/        splash, auth, home, contacts, profile, call, history
├── widgets/        UserTile, buttons, call controls, presence/incoming gate
├── router/         go_router
└── main.dart
```

### How a call is established

1. Caller creates `calls/{id}` in Firestore with `status: ringing` and `channelName`.
2. Callee’s `incomingCallProvider` (Firestore query on `calleeId` + `ringing`) opens **Incoming Call**.
3. Accept writes `status: accepted`. Both users `joinChannel` on Agora with the same channel and a stable integer UID derived from Firebase UID.
4. Agora `onUserJoined` → UI phase **In Call** and duration timer starts.
5. Hang up / reject / timeout writes a terminal status (`ended`, `rejected`, `missed`, …) which **is** the history record.

Incoming detection does **not** require FCM while both apps are in the foreground. FCM is for background/killed devices after you deploy `functions/index.js`.

## Call state machine

`Calling → Ringing → Connected → In Call → Ended`

Also handled in UI: **Rejected, Missed, Busy, Failed, Disconnected**.

## Firestore schema

**`users/{uid}`**

| Field | Type |
|---|---|
| uid, name, email, phone, photoUrl | string |
| isOnline | bool |
| lastSeen | timestamp |
| fcmToken | string |
| blockedUids | string[] |

**`calls/{callId}`**

| Field | Type |
|---|---|
| callerId, calleeId, callerName, calleeName | string |
| type | `audio` \| `video` |
| status | ringing, accepted, rejected, busy, missed, ended, failed, disconnected |
| channelName, participants | string / string[] |
| createdAt, answeredAt, endedAt | timestamp |
| durationSeconds | number |

Deploy rules and indexes from the repo root:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

## Setup

### 1. Flutter

- Flutter **3.32.0** (or latest stable) / Dart **3.8+**
- Android Studio / SDK (minSdk **24**)

### 2. Firebase

1. Create a Firebase project.
2. Enable **Authentication → Email/Password**.
3. Create **Cloud Firestore** (start in test mode, then deploy `firestore.rules`).
4. Register Android app id `com.connectcall.connect_call` (and iOS if needed).
5. Download `google-services.json` into `android/app/`.
6. Generate options:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

That overwrites `lib/firebase_options.dart`. Until then the app shows an in-app setup screen instead of crashing.

### 3. Agora

1. Create a project at [console.agora.io](https://console.agora.io/).
2. Copy the **App ID**.
3. For intern testing, **disable App Certificate** so an empty token works. (Enable certificate + token server before production.)

Run:

```bash
flutter pub get
flutter run --dart-define=AGORA_APP_ID=YOUR_AGORA_APP_ID
```

Two devices/emulators, two accounts. Grant mic/camera when prompted.

### 4. Bonus: background incoming FCM

Deploy `functions/index.js` after `firebase init functions`. Tokens are saved on login/resume.

## Packages

`flutter_riverpod`, `go_router`, `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`, `agora_rtc_engine`, `permission_handler`, `connectivity_plus`, `google_fonts`, `intl`, `uuid`, `shared_preferences`.

## Android APK

After Firebase + Agora are configured:

```bash
flutter build apk --dart-define=AGORA_APP_ID=YOUR_AGORA_APP_ID
```

Output: `build/app/outputs/flutter-apk/app-release.apk`  
Release is signed with the debug keystore in this intern template (`android/app/build.gradle.kts`) so `flutter run --release` works. Replace with a real keystore for store distribution.

## Known limitations

- Phone login maps digits to `number@users.connectcall.app`. Registration is email-based; use email for both accounts unless you also create that alias.
- Agora testing mode (no certificate) is **not** production-safe.
- Presence is lifecycle-based (foreground = online). Force-kill may leave `isOnline` true until next session.
- No Cloud Function in the default path: background/killed incoming calls need the optional function + notification tap handling.
- Group call, screen share, and call recording are not implemented.
- iOS requires `GoogleService-Info.plist` + microphone/camera Info.plist keys (already added).
- Demo video is not included in the repo; record on two phones for submission.

## How to scale

- Replace empty Agora tokens with a Cloud Function that mints RTC tokens.
- Move signaling to a dedicated `callSessions` collection + presence via RTDB `onDisconnect`.
- Add a token/Cloud Function gate so only callee/caller can join a channel.
- Split `CallController` into signaling vs media notifiers if you add groups.

## AI tools used

Developed with **Cursor Grok 4.6** (Cursor IDE agent). No Copilot/ChatGPT session was used for this codebase beyond that assistant.

## Review talking points

- **Why Flutter:** shared UI + plugins for Agora and Firebase; widgets rebuild from immutable configuration when `setState` / Riverpod notify.
- **Async:** `Future`/`Stream` in services; UI uses `AsyncValue.when` and `ref.listen` so errors become snackbars, not crashes.
- **Permissions:** `PermissionHelper.ensureCall` before join; denied dialog vs Settings deep-link.
- **Agora:** both peers join the same `channelName`; UID is a stable hash of Firebase UID; mute/camera map to Agora APIs; peer leave → `disconnected`.
