import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_config.dart';
import '../models/call_model.dart';
import '../providers/providers.dart';

class IncomingCallGate extends ConsumerWidget {
  const IncomingCallGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<CallModel?>>(
      incomingCallProvider,
      (previous, next) {
        final call = next.valueOrNull;

        if (call == null) {
          return;
        }

        final session = ref.read(callControllerProvider);

        if (session.isActive) {
          return;
        }

        final location =
            GoRouterState.of(context).matchedLocation;

        if (location.startsWith('/call')) {
          return;
        }

        context.push('/call/incoming');
      },
    );

    return child;
  }
}
class PresenceBinder extends ConsumerStatefulWidget {
  const PresenceBinder({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PresenceBinder> createState() => _PresenceBinderState();
}

class _PresenceBinderState extends ConsumerState<PresenceBinder>
    with WidgetsBindingObserver {
  Timer? _heartbeat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _goOnline());
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _set(bool online) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await ref.read(userServiceProvider).setOnline(uid, online: online);
  }

  Future<void> _goOnline() async {
    await _set(true);
    await _bindPush();
    await _reap();
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(AppConfig.presenceHeartbeat, (_) async {
      await _set(true);
      await _reap();
    });
  }

  Future<void> _reap() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      await ref.read(callingServiceProvider).reapStaleCalls(uid);
    } catch (_) {
      // Presence should not fail the UI if a stale-call write is denied.
    }
  }

  Future<void> _bindPush() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) {
        await ref.read(userServiceProvider).saveFcmToken(uid, token);
      }
      await ref.read(userServiceProvider).removeLegacyFcmToken(uid);
    } catch (_) {
      // Push is a bonus path; foreground calling still works via Firestore.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _goOnline();
        FirebaseFirestore.instance.enableNetwork();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Do not flip isOnline here. Android sends paused for permission
        // sheets and the recents screen, which was reporting false offline.
        break;
      case AppLifecycleState.detached:
        _heartbeat?.cancel();
        _set(false);
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (prev, next) {
      if (next.valueOrNull != null) {
        _goOnline();
      } else {
        _heartbeat?.cancel();
      }
    });
    return widget.child;
  }
}
