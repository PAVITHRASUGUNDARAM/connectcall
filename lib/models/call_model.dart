import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_config.dart';

enum CallType {
  audio,
  video,
}

enum CallStatus {
  ringing,
  accepted,
  rejected,
  busy,
  missed,
  cancelled,
  ended,
  failed,
  disconnected,
}

enum CallPhase {
  idle,
  calling,
  ringing,
  connected,
  inCall,
  ended,
  rejected,
  missed,
  cancelled,
  busy,
  failed,
  disconnected,
}

class CallModel {
  const CallModel({
    required this.id,
    required this.callerId,
    required this.calleeId,
    required this.callerName,
    required this.calleeName,
    required this.type,
    required this.status,
    required this.channelName,
    required this.participants,
    this.callerPhoto,
    this.calleePhoto,
    this.createdAt,
    this.answeredAt,
    this.endedAt,
    this.aliveAt,
    this.durationSeconds = 0,
  });

  final String id;
  final String callerId;
  final String calleeId;

  final String callerName;
  final String calleeName;

  final String? callerPhoto;
  final String? calleePhoto;

  final CallType type;
  final CallStatus status;

  final String channelName;
  final List<String> participants;

  final DateTime? createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final DateTime? aliveAt;

  final int durationSeconds;

  bool get isVideo => type == CallType.video;

  bool get isMissed => status == CallStatus.missed;

  bool isIncomingFor(String uid) => calleeId == uid;

  bool isOutgoingFor(String uid) => callerId == uid;

  String peerName(String uid) {
    return uid == callerId ? calleeName : callerName;
  }

  String? peerPhoto(String uid) {
    return uid == callerId ? calleePhoto : callerPhoto;
  }

  String peerId(String uid) {
    return uid == callerId ? calleeId : callerId;
  }

  static bool _isFresh(
    DateTime? at,
    Duration maxAge,
  ) {
    // Firestore serverTimestamp can temporarily be null
    // immediately after a document is created.
    //
    // In that situation we consider the call fresh and allow
    // the incoming-call listener to receive it.
    if (at == null) {
      return true;
    }

    return DateTime.now().difference(at) < maxAge;
  }

  /// Returns true when the call should still be treated as active.
  ///
  /// Ringing calls are considered active according to the ring timeout.
  /// Accepted calls are considered active according to the heartbeat.
  bool get isGenuinelyActive {
    switch (status) {
      case CallStatus.ringing:
        return _isFresh(
          createdAt,
          AppConfig.callRingTimeout,
        );

      case CallStatus.accepted:
        return _isFresh(
          aliveAt ?? answeredAt ?? createdAt,
          AppConfig.callAliveTimeout,
        );

      default:
        return false;
    }
  }

  CallModel copyWith({
    CallStatus? status,
    DateTime? answeredAt,
    DateTime? endedAt,
    DateTime? aliveAt,
    int? durationSeconds,
  }) {
    return CallModel(
      id: id,
      callerId: callerId,
      calleeId: calleeId,
      callerName: callerName,
      calleeName: calleeName,
      callerPhoto: callerPhoto,
      calleePhoto: calleePhoto,
      type: type,
      status: status ?? this.status,
      channelName: channelName,
      participants: participants,
      createdAt: createdAt,
      answeredAt: answeredAt ?? this.answeredAt,
      endedAt: endedAt ?? this.endedAt,
      aliveAt: aliveAt ?? this.aliveAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'callerId': callerId,
      'calleeId': calleeId,
      'callerName': callerName,
      'calleeName': calleeName,
      'callerPhoto': callerPhoto,
      'calleePhoto': calleePhoto,
      'type': type.name,
      'status': status.name,
      'channelName': channelName,
      'participants': participants,

      // IMPORTANT:
      // Always let Firestore generate the timestamp.
      'createdAt': FieldValue.serverTimestamp(),

      'answeredAt': answeredAt == null
          ? null
          : Timestamp.fromDate(answeredAt!),

      'endedAt': endedAt == null
          ? null
          : Timestamp.fromDate(endedAt!),

      'aliveAt': aliveAt == null
          ? null
          : Timestamp.fromDate(aliveAt!),

      'durationSeconds': durationSeconds,
    };
  }

  static CallType _type(String? raw) {
    return raw == CallType.video.name
        ? CallType.video
        : CallType.audio;
  }

  static CallStatus _status(String? raw) {
    return CallStatus.values.firstWhere(
      (status) => status.name == raw,
      orElse: () => CallStatus.ringing,
    );
  }

  static DateTime? _timestampToDateTime(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  factory CallModel.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    final participantsRaw = map['participants'];

    return CallModel(
      id: map['id'] as String? ?? id,

      callerId: map['callerId'] as String? ?? '',
      calleeId: map['calleeId'] as String? ?? '',

      callerName: map['callerName'] as String? ?? 'Unknown',
      calleeName: map['calleeName'] as String? ?? 'Unknown',

      callerPhoto: map['callerPhoto'] as String?,
      calleePhoto: map['calleePhoto'] as String?,

      type: _type(map['type'] as String?),
      status: _status(map['status'] as String?),

      channelName: map['channelName'] as String? ?? id,

      participants: participantsRaw is List
          ? List<String>.from(participantsRaw)
          : const [],

      createdAt: _timestampToDateTime(
        map['createdAt'],
      ),

      answeredAt: _timestampToDateTime(
        map['answeredAt'],
      ),

      endedAt: _timestampToDateTime(
        map['endedAt'],
      ),

      aliveAt: _timestampToDateTime(
        map['aliveAt'],
      ),

      durationSeconds: map['durationSeconds'] is int
          ? map['durationSeconds'] as int
          : 0,
    );
  }

  factory CallModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return CallModel.fromMap(
      doc.data() ?? <String, dynamic>{},
      doc.id,
    );
  }
}