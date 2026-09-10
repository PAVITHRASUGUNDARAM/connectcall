import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_config.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    bool isOnline = false,
    this.lastSeen,
    this.blockedUids = const [],
  }) : _onlineFlag = isOnline;

  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final bool _onlineFlag;
  final DateTime? lastSeen;
  final List<String> blockedUids;

  /// True only if lastSeen is recent. A stuck Firestore boolean is ignored.
  bool get isOnline => presenceFrom(_onlineFlag, lastSeen);

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  bool blocks(String otherUid) => blockedUids.contains(otherUid);

  static bool presenceFrom(bool storedOnline, DateTime? lastSeen) {
    if (!storedOnline) return false;
    if (lastSeen == null) return true;
    return DateTime.now().difference(lastSeen) < AppConfig.presenceTtl;
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? photoUrl,
    bool? isOnline,
    DateTime? lastSeen,
    List<String>? blockedUids,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      isOnline: isOnline ?? _onlineFlag,
      lastSeen: lastSeen ?? this.lastSeen,
      blockedUids: blockedUids ?? this.blockedUids,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'isOnline': _onlineFlag,
      'lastSeen': lastSeen == null ? null : Timestamp.fromDate(lastSeen!),
      'blockedUids': blockedUids,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: map['uid'] as String? ?? id,
      name: map['name'] as String? ?? 'Unknown',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String?,
      photoUrl: map['photoUrl'] as String?,
      isOnline: map['isOnline'] as bool? ?? false,
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate(),
      blockedUids: List<String>.from(map['blockedUids'] as List? ?? const []),
    );
  }

  factory UserModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserModel.fromMap(doc.data() ?? {}, doc.id);
  }
}
