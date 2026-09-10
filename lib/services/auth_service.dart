import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import 'user_service.dart';

class AuthService {
  AuthService(this._auth, this._users);

  final FirebaseAuth _auth;
  final UserService _users;

  Stream<User?> authState() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user!.updateDisplayName(name.trim());
    final model = UserModel(
      uid: cred.user!.uid,
      name: name.trim(),
      email: email.trim(),
      isOnline: true,
      lastSeen: DateTime.now(),
    );
    await _users.upsert(model);
    return model;
  }

  Future<UserModel> login({
    required String emailOrPhone,
    required String password,
  }) async {
    final identifier = emailOrPhone.trim();
    final email = identifier.contains('@')
        ? identifier
        : '$identifier@${_phoneAliasDomain()}';
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final existing = await _users.getById(cred.user!.uid);
    try {
      await _users.removeLegacyFcmToken(cred.user!.uid);
    } catch (_) {
      // Existing installations may not have the legacy field.
    }
    final model = existing ??
        UserModel(
          uid: cred.user!.uid,
          name: cred.user!.displayName ?? 'User',
          email: cred.user!.email ?? email,
          isOnline: true,
          lastSeen: DateTime.now(),
        );
    await _users.setOnline(model.uid, online: true);
    if (existing == null) {
      await _users.upsert(model.copyWith(isOnline: true, lastSeen: DateTime.now()));
    }
    return model.copyWith(isOnline: true, lastSeen: DateTime.now());
  }

  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _users.setOnline(uid, online: false);
    }
    await _auth.signOut();
  }

  String _phoneAliasDomain() => 'users.connectcall.app';
}
