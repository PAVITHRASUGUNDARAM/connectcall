import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';
import 'router/app_router.dart';
import 'widgets/app_lifecycle.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!DefaultFirebaseOptions.isConfigured) {
    runApp(const SetupRequiredApp());
    return;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const ProviderScope(child: ConnectCallApp()));
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class ConnectCallApp extends ConsumerWidget {
  const ConnectCallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return PresenceBinder(
      child: MaterialApp.router(
        title: AppStrings.appName,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        routerConfig: router,
        builder: (context, child) {
          return IncomingCallGate(child: child ?? const SizedBox.shrink());
        },
      ),
    );
  }
}

class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      theme: AppTheme.light(),
      home: const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ConnectCall setup',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 12),
                Text(
                  'Firebase options are still placeholders. Complete these steps, then hot-restart:',
                ),
                SizedBox(height: 16),
                Text('1. Create a Firebase project and enable Auth (Email/Password) + Firestore.'),
                Text('2. Run: dart pub global activate flutterfire_cli'),
                Text('3. Run: flutterfire configure'),
                Text('4. Add android/app/google-services.json (and iOS GoogleService-Info.plist).'),
                Text('5. Create an Agora project, disable the App Certificate for testing, and run:'),
                SizedBox(height: 8),
                Text('flutter run --dart-define=AGORA_APP_ID=your_agora_app_id'),
                SizedBox(height: 16),
                Text('See README.md for the full setup, Firestore rules, and demo notes.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
