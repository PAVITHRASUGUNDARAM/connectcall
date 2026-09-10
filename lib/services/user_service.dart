import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_config.dart';
import '../models/user_model.dart';

class UserService {
  UserService(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.users);

  Future<void> upsert(UserModel user) {
    return _col.doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  Future<UserModel?> getById(String uid) async {
    final snap = await _col.doc(uid).get();
    if (!snap.exists) return null;
    return UserModel.fromDoc(snap);
  }

  Stream<UserModel?> watchById(String uid) {
    return _col.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromDoc(doc);
    });
  }

  Stream<List<UserModel>> watchAllExcept(String uid) {
    return _col.snapshots().map((snap) {
      return snap.docs
          .map(UserModel.fromDoc)
          .where((u) => u.uid != uid)
          .toList()
        ..sort((a, b) {
          if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    });
  }

  Future<void> setOnline(String uid, {required bool online}) {
    return _col.doc(uid).set({
      'isOnline': online,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateProfile({
    required String uid,
    required String name,
    String? phone,
    String? photoUrl,
  }) {
    return _col.doc(uid).set({
      'name': name.trim(),
      'phone': phone?.trim(),
      'photoUrl': photoUrl?.trim(),
    }, SetOptions(merge: true));
  }

  Future<void> saveFcmToken(String uid, String token) {
    final tokenId = Uri.encodeComponent(token);
    return _db
        .collection(FirestorePaths.userDevices)
        .doc(uid)
        .collection(FirestorePaths.deviceTokens)
        .doc(tokenId)
        .set({
          'token': token,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> removeLegacyFcmToken(String uid) {
    // One-time cleanup for documents created by the older app version.
    return _col.doc(uid).update({'fcmToken': FieldValue.delete()});
  }

  Future<void> toggleBlock({
    required String uid,
    required String otherUid,
    required bool block,
  }) async {
    await _col.doc(uid).set({
      'blockedUids': block
          ? FieldValue.arrayUnion([otherUid])
          : FieldValue.arrayRemove([otherUid]),
    }, SetOptions(merge: true));
  }
}
