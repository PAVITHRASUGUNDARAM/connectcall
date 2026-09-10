import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/call_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/calling_service.dart';
import '../services/user_service.dart';
import 'call_controller.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final userServiceProvider = Provider<UserService>(
  (ref) => UserService(ref.watch(firestoreProvider)),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    ref.watch(firebaseAuthProvider),
    ref.watch(userServiceProvider),
  ),
);

final callingServiceProvider = Provider<CallingService>((ref) {
  final service = CallingService(ref.watch(firestoreProvider));
  ref.onDispose(service.disposeEngine);
  return service;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authState();
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value(null);
  return ref.watch(userServiceProvider).watchById(auth.uid);
});

final presenceClockProvider = StreamProvider<int>((ref) {
  return Stream<int>.periodic(const Duration(seconds: 15), (i) => i);
});

final contactsProvider = StreamProvider<List<UserModel>>((ref) {
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (me == null) return Stream.value(const []);
  return ref.watch(userServiceProvider).watchAllExcept(me.uid).map((users) {
    return users.where((u) => !me.blocks(u.uid) && !u.blocks(me.uid)).toList();
  });
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredContactsProvider = Provider<List<UserModel>>((ref) {
  ref.watch(presenceClockProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final contacts = ref.watch(contactsProvider).valueOrNull ?? const [];
  if (query.isEmpty) return contacts;
  return contacts
      .where(
        (u) =>
            u.name.toLowerCase().contains(query) ||
            u.email.toLowerCase().contains(query),
      )
      .toList();
});

final callHistoryProvider = StreamProvider<List<CallModel>>((ref) {
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (me == null) return Stream.value(const []);
  return ref.watch(callingServiceProvider).watchHistory(me.uid);
});

final incomingCallProvider = StreamProvider<CallModel?>((ref) {
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (me == null) return Stream.value(null);
  return ref.watch(callingServiceProvider).watchIncoming(me.uid);
});

final callControllerProvider =
    StateNotifierProvider<CallController, CallSession>((ref) {
  return CallController(ref.watch(callingServiceProvider));
});

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(),
);

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _load();
  }

  static const _key = 'theme_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    state = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> cycle() async {
    final next = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      switch (next) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }
}
