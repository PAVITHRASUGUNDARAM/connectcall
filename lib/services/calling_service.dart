import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_config.dart';
import '../core/utils/agora_uid.dart';
import '../models/call_model.dart';
import '../models/user_model.dart';

enum NetworkQuality {
  unknown,
  good,
  fair,
  poor,
}

class CallingService {
  CallingService(this._db);

  final FirebaseFirestore _db;
  final Uuid _uuid = const Uuid();

  RtcEngine? _engine;

  StreamController<int>? _remoteUid;
  StreamController<NetworkQuality>? _quality;
  StreamController<String>? _engineErrors;

  Completer<void>? _joinWaiter;

  int? lastRemoteUid;

  CollectionReference<Map<String, dynamic>> get _calls =>
      _db.collection(FirestorePaths.calls);

  // ---------------------------------------------------------------------------
  // STREAMS USED BY CALL CONTROLLER
  // ---------------------------------------------------------------------------

  Stream<int> get remoteUid$ =>
      _remoteUid?.stream ?? const Stream.empty();

  Stream<NetworkQuality> get quality$ =>
      _quality?.stream ?? const Stream.empty();

  Stream<String> get engineErrors$ =>
      _engineErrors?.stream ?? const Stream.empty();

  RtcEngine? get engine => _engine;

  // ---------------------------------------------------------------------------
  // AGORA ENGINE
  // ---------------------------------------------------------------------------

  Future<RtcEngine> ensureEngine({
    required bool video,
  }) async {
    if (!AppConfig.isAgoraConfigured) {
      throw StateError(
        'Agora App ID is missing. Set AGORA_APP_ID via --dart-define.',
      );
    }

    // Engine already exists.
    if (_engine != null) {
      if (video) {
        await _engine!.enableVideo();
        await _engine!.startPreview();
      } else {
        try {
          await _engine!.stopPreview();
        } catch (_) {}

        await _engine!.disableVideo();
      }

      return _engine!;
    }

    // Create controllers before registering Agora callbacks.
    _remoteUid = StreamController<int>.broadcast();
    _quality = StreamController<NetworkQuality>.broadcast();
    _engineErrors = StreamController<String>.broadcast();

    lastRemoteUid = null;

    final engine = createAgoraRtcEngine();

    await engine.initialize(
      RtcEngineContext(
        appId: AppConfig.agoraAppId,
        channelProfile:
            ChannelProfileType.channelProfileCommunication,
      ),
    );

    engine.registerEventHandler(
      RtcEngineEventHandler(
        // ---------------------------------------------------------------
        // LOCAL USER JOINED
        // ---------------------------------------------------------------
        onJoinChannelSuccess: (
          RtcConnection connection,
          int elapsed,
        ) {
          final waiter = _joinWaiter;

          if (waiter != null && !waiter.isCompleted) {
            waiter.complete();
          }
        },

        // ---------------------------------------------------------------
        // REMOTE USER JOINED
        // ---------------------------------------------------------------
        onUserJoined: (
          RtcConnection connection,
          int remoteUid,
          int elapsed,
        ) {
          lastRemoteUid = remoteUid;
          _remoteUid?.add(remoteUid);
        },

        // ---------------------------------------------------------------
        // REMOTE USER LEFT
        // ---------------------------------------------------------------
        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          if (lastRemoteUid == remoteUid) {
            lastRemoteUid = null;
          }

          _remoteUid?.add(0);
        },

        // ---------------------------------------------------------------
        // CONNECTION STATE
        // ---------------------------------------------------------------
        onConnectionStateChanged: (
          RtcConnection connection,
          ConnectionStateType state,
          ConnectionChangedReasonType reason,
        ) {
          if (state ==
              ConnectionStateType.connectionStateFailed) {
            _failJoin('Media connection failed');
          }
        },

        // ---------------------------------------------------------------
        // AGORA ERROR
        // ---------------------------------------------------------------
        onError: (
          ErrorCodeType err,
          String msg,
        ) {
          if (!_isFatalAgoraError(err)) {
            return;
          }

          final text =
              msg.isNotEmpty ? msg : err.toString();

          _failJoin(text);
        },

        // ---------------------------------------------------------------
        // NETWORK QUALITY
        //
        // Agora SDK 6.5.2 provides:
        // connection, uid, txQuality, rxQuality
        // ---------------------------------------------------------------
        onNetworkQuality: (
          RtcConnection connection,
          int uid,
          QualityType txQuality,
          QualityType rxQuality,
        ) {
          _quality?.add(
            _mapQuality(
              txQuality,
              rxQuality,
            ),
          );
        },
      ),
    );

    // Audio is always enabled.
    await engine.enableAudio();

    // Enable video only when required.
    if (video) {
      await engine.enableVideo();
      await engine.startPreview();
    }

    await engine.setClientRole(
      role: ClientRoleType.clientRoleBroadcaster,
    );

    _engine = engine;

    return engine;
  }

  // ---------------------------------------------------------------------------
  // JOIN AGORA CHANNEL
  // ---------------------------------------------------------------------------

  Future<void> joinChannel({
    required String channelName,
    required String firebaseUid,
    required bool video,
  }) async {
    final engine = await ensureEngine(video: video);

    final uid = agoraUidFrom(firebaseUid);

    final token = _rtcToken(
      channelName,
      uid,
    );

    _joinWaiter = Completer<void>();
    lastRemoteUid = null;

    await engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: ChannelMediaOptions(
        clientRoleType:
            ClientRoleType.clientRoleBroadcaster,
        channelProfile:
            ChannelProfileType.channelProfileCommunication,
        publishMicrophoneTrack: true,
        publishCameraTrack: video,
        autoSubscribeAudio: true,
        autoSubscribeVideo: video,
      ),
    );

    try {
      await _joinWaiter!.future.timeout(
        const Duration(seconds: 20),
      );
    } on TimeoutException {
      throw StateError(
        'Could not join the media channel. '
        'Check Agora App ID, token, and network.',
      );
    } finally {
      _joinWaiter = null;
    }
  }

  // ---------------------------------------------------------------------------
  // AGORA TOKEN
  // ---------------------------------------------------------------------------

  String _rtcToken(
    String channelName,
    int uid,
  ) {
    // Static token from AppConfig.
    //
    // If you are using Agora testing mode where token is not required,
    // this can return an empty string.
    //
    // Your security patch removed the client-side token generator,
    // so do NOT put the App Certificate in this file.

    if (AppConfig.agoraToken.isNotEmpty) {
      return AppConfig.agoraToken;
    }

    return '';
  }

  // ---------------------------------------------------------------------------
  // AGORA JOIN FAILURE
  // ---------------------------------------------------------------------------

  void _failJoin(String message) {
    final waiter = _joinWaiter;

    if (waiter != null && !waiter.isCompleted) {
      waiter.completeError(
        StateError(message),
      );
    }

    _engineErrors?.add(message);
  }

  static bool _isFatalAgoraError(
    ErrorCodeType err,
  ) {
    switch (err) {
      case ErrorCodeType.errInvalidAppId:
      case ErrorCodeType.errInvalidToken:
      case ErrorCodeType.errTokenExpired:
      case ErrorCodeType.errInvalidChannelName:
        return true;

      default:
        return false;
    }
  }

  // ---------------------------------------------------------------------------
  // LEAVE CHANNEL
  // ---------------------------------------------------------------------------

  Future<void> leaveChannel() async {
    try {
      await _engine?.leaveChannel();
    } catch (_) {}

    try {
      await _engine?.stopPreview();
    } catch (_) {}

    lastRemoteUid = null;
  }

  // ---------------------------------------------------------------------------
  // AUDIO CONTROLS
  // ---------------------------------------------------------------------------

  Future<void> muteLocalAudio(
    bool muted,
  ) {
    return _engine?.muteLocalAudioStream(muted) ??
        Future.value();
  }

  Future<void> setSpeakerphone(
    bool on,
  ) {
    return _engine?.setEnableSpeakerphone(on) ??
        Future.value();
  }

  // ---------------------------------------------------------------------------
  // VIDEO CONTROLS
  // ---------------------------------------------------------------------------

  Future<void> muteLocalVideo(
    bool muted,
  ) async {
    if (_engine == null) {
      return;
    }

    await _engine!.muteLocalVideoStream(muted);

    await _engine!.enableLocalVideo(!muted);
  }

  Future<void> switchCamera() {
    return _engine?.switchCamera() ??
        Future.value();
  }

  // ---------------------------------------------------------------------------
  // CREATE OUTGOING CALL
  // ---------------------------------------------------------------------------

  Future<CallModel> createOutgoingCall({
    required UserModel caller,
    required UserModel callee,
    required CallType type,
  }) async {
    final busy = await _hasActiveCall(
      callee.uid,
    );

    final id = _uuid.v4();

    final call = CallModel(
      id: id,
      callerId: caller.uid,
      calleeId: callee.uid,
      callerName: caller.name,
      calleeName: callee.name,
      callerPhoto: caller.photoUrl,
      calleePhoto: callee.photoUrl,
      type: type,
      status: busy
          ? CallStatus.busy
          : CallStatus.ringing,

      // IMPORTANT:
      // CallModel requires channelName and participants.
      channelName: id.replaceAll('-', ''),

      participants: [
        caller.uid,
        callee.uid,
      ],

      createdAt: DateTime.now(),
    );

    await _calls.doc(id).set(
      call.toMap(),
    );

    return call;
  }

  // ---------------------------------------------------------------------------
  // CHECK ACTIVE CALL
  // ---------------------------------------------------------------------------

  Future<bool> _hasActiveCall(
    String uid,
  ) async {
    final snap = await _calls
        .where(
          'participants',
          arrayContains: uid,
        )
        .where(
          'status',
          whereIn: [
            CallStatus.ringing.name,
            CallStatus.accepted.name,
          ],
        )
        .limit(10)
        .get();

    var busy = false;

    for (final doc in snap.docs) {
      final call = CallModel.fromDoc(doc);

      if (call.isGenuinelyActive) {
        busy = true;
      } else {
        await _finalize(
          call.id,
          call.status == CallStatus.ringing
              ? CallStatus.missed
              : CallStatus.failed,
        );
      }
    }

    return busy;
  }

  // ---------------------------------------------------------------------------
  // REAP STALE CALLS
  // ---------------------------------------------------------------------------

  Future<void> reapStaleCalls(
    String uid,
  ) async {
    await _hasActiveCall(uid);
  }

  // ---------------------------------------------------------------------------
  // CALL HEARTBEAT
  // ---------------------------------------------------------------------------

  Future<void> touchAlive(
    String callId,
  ) {
    return _calls.doc(callId).set(
      {
        'aliveAt': FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WATCH CALL
  // ---------------------------------------------------------------------------

  Stream<CallModel?> watchCall(
    String callId,
  ) {
    return _calls.doc(callId).snapshots().map(
      (doc) {
        if (!doc.exists) {
          return null;
        }

        try {
          return CallModel.fromDoc(doc);
        } catch (_) {
          return null;
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // WATCH INCOMING CALL
  // ---------------------------------------------------------------------------
  //
  // IMPORTANT:
  // We query participants only and filter callee/status
  // locally. This avoids requiring a composite Firestore
  // index for participants + calleeId + status.
  //

  Stream<CallModel?> watchIncoming(String uid) {
  return _db
      .collection(FirestorePaths.calls)
      .where(
        'participants',
        arrayContains: uid,
      )
      .snapshots()
      .map((snapshot) {
        final calls = snapshot.docs
            .map(CallModel.fromDoc)
            .where((call) {
          return call.calleeId == uid &&
              call.status == CallStatus.ringing;
        })
            .toList();

        calls.sort((a, b){
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

          return bTime.compareTo(aTime);
        });
        return calls.isEmpty ? null : calls.first;
      });
  }
  

  // ---------------------------------------------------------------------------
  // CALL HISTORY
  // ---------------------------------------------------------------------------

  Stream<List<CallModel>> watchHistory(
    String uid,
  ) {
    return _calls
        .where(
          'participants',
          arrayContains: uid,
        )
        .snapshots()
        .map(
      (snap) {
        final items = snap.docs
            .map(
              CallModel.fromDoc,
            )
            .toList()
          ..sort(
            (a, b) {
              final aMs =
                  a.createdAt
                          ?.millisecondsSinceEpoch ??
                      0;

              final bMs =
                  b.createdAt
                          ?.millisecondsSinceEpoch ??
                      0;

              return bMs.compareTo(aMs);
            },
          );

        return items
            .where(
              (call) =>
                  call.status !=
                      CallStatus.ringing &&
                  call.status !=
                      CallStatus.accepted,
            )
            .toList();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ACCEPT
  // ---------------------------------------------------------------------------

  Future<void> accept(
    String callId,
  ) {
    return _calls.doc(callId).set(
      {
        'status': CallStatus.accepted.name,
        'answeredAt': FieldValue.serverTimestamp(),
        'aliveAt': FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REJECT
  // ---------------------------------------------------------------------------

  Future<void> reject(
    String callId,
  ) {
    return _finalize(
      callId,
      CallStatus.rejected,
    );
  }

  // ---------------------------------------------------------------------------
  // CANCEL
  // ---------------------------------------------------------------------------

  Future<void> cancel(
    String callId,
  ) {
    return _finalize(
      callId,
      CallStatus.cancelled,
    );
  }

  // ---------------------------------------------------------------------------
  // MISSED
  // ---------------------------------------------------------------------------

  Future<void> markMissed(
    String callId,
  ) {
    return _finalize(
      callId,
      CallStatus.missed,
    );
  }

  // ---------------------------------------------------------------------------
  // FAILED
  // ---------------------------------------------------------------------------

  Future<void> markFailed(
    String callId,
  ) {
    return _finalize(
      callId,
      CallStatus.failed,
    );
  }

  // ---------------------------------------------------------------------------
  // END CALL
  // ---------------------------------------------------------------------------

  Future<void> endCall(
    String callId, {
    required int durationSeconds,
  }) {
    return _finalize(
      callId,
      CallStatus.ended,
      durationSeconds: durationSeconds,
    );
  }

  // ---------------------------------------------------------------------------
  // DISCONNECTED
  // ---------------------------------------------------------------------------

  Future<void> markDisconnected(
    String callId, {
    required int durationSeconds,
  }) {
    return _finalize(
      callId,
      CallStatus.disconnected,
      durationSeconds: durationSeconds,
    );
  }

  // ---------------------------------------------------------------------------
  // FINALIZE CALL
  // ---------------------------------------------------------------------------

  Future<void> _finalize(
    String callId,
    CallStatus status, {
    int durationSeconds = 0,
  }) async {
    final ref = _calls.doc(callId);

    await _db.runTransaction(
      (tx) async {
        final snap = await tx.get(ref);

        if (!snap.exists) {
          return;
        }

        final current =
            snap.data()?['status'] as String?;

        // Do not overwrite already completed calls.
        if (current != CallStatus.ringing.name &&
            current != CallStatus.accepted.name) {
          return;
        }

        tx.update(
          ref,
          {
            'status': status.name,
            'endedAt':
                FieldValue.serverTimestamp(),
            'durationSeconds': durationSeconds,
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // NETWORK QUALITY
  // ---------------------------------------------------------------------------

  static NetworkQuality _mapQuality(
    QualityType tx,
    QualityType rx,
  ) {
    int rank(
      QualityType quality,
    ) {
      switch (quality) {
        case QualityType.qualityExcellent:
        case QualityType.qualityGood:
          return 3;

        case QualityType.qualityPoor:
        case QualityType.qualityBad:
          return 2;

        case QualityType.qualityVbad:
        case QualityType.qualityDown:
          return 1;

        default:
          return 0;
      }
    }

    final txRank = rank(tx);
    final rxRank = rank(rx);

    final worst =
        txRank < rxRank ? txRank : rxRank;

    if (worst >= 3) {
      return NetworkQuality.good;
    }

    if (worst == 2) {
      return NetworkQuality.fair;
    }

    if (worst == 1) {
      return NetworkQuality.poor;
    }

    return NetworkQuality.unknown;
  }

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------

  Future<void> disposeEngine() async {
    await leaveChannel();

    try {
      await _engine?.release();
    } catch (_) {}

    _engine = null;

    await _remoteUid?.close();
    await _quality?.close();
    await _engineErrors?.close();

    _remoteUid = null;
    _quality = null;
    _engineErrors = null;
    _joinWaiter = null;
    lastRemoteUid = null;
  }
}