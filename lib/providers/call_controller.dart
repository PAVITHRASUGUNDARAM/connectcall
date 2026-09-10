import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_config.dart';
import '../models/call_model.dart';
import '../models/user_model.dart';
import '../services/calling_service.dart';

class CallSession {
  const CallSession({
    this.call,
    this.phase = CallPhase.idle,
    this.muted = false,
    this.speakerOn = true,
    this.cameraOff = false,
    this.remoteUid,
    this.duration = Duration.zero,
    this.quality = NetworkQuality.unknown,
    this.errorMessage,
    this.isCaller = true,
  });

  final CallModel? call;
  final CallPhase phase;
  final bool muted;
  final bool speakerOn;
  final bool cameraOff;
  final int? remoteUid;
  final Duration duration;
  final NetworkQuality quality;
  final String? errorMessage;
  final bool isCaller;

  bool get isActive =>
      phase == CallPhase.calling ||
      phase == CallPhase.ringing ||
      phase == CallPhase.connected ||
      phase == CallPhase.inCall;

  CallSession copyWith({
    CallModel? call,
    CallPhase? phase,
    bool? muted,
    bool? speakerOn,
    bool? cameraOff,
    int? remoteUid,
    Duration? duration,
    NetworkQuality? quality,
    String? errorMessage,
    bool? isCaller,
    bool clearRemote = false,
    bool clearError = false,
  }) {
    return CallSession(
      call: call ?? this.call,
      phase: phase ?? this.phase,
      muted: muted ?? this.muted,
      speakerOn: speakerOn ?? this.speakerOn,
      cameraOff: cameraOff ?? this.cameraOff,
      remoteUid: clearRemote ? null : (remoteUid ?? this.remoteUid),
      duration: duration ?? this.duration,
      quality: quality ?? this.quality,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isCaller: isCaller ?? this.isCaller,
    );
  }
}

class CallController extends StateNotifier<CallSession> {
  CallController(this._calling) : super(const CallSession());

  final CallingService _calling;

  Timer? _ringTimer;
  Timer? _tick;
  Timer? _aliveTimer;
  StreamSubscription<CallModel?>? _docSub;
  StreamSubscription<int>? _remoteSub;
  StreamSubscription<NetworkQuality>? _qualitySub;
  StreamSubscription<String>? _errorSub;
  bool _joined = false;

  Future<CallModel> startCall({
    required UserModel me,
    required UserModel peer,
    required CallType type,
  }) async {
    await _assertOnline();
    if (!AppConfig.isAgoraConfigured) {
      throw StateError('Agora is not configured. Add AGORA_APP_ID.');
    }

    final call = await _calling.createOutgoingCall(
      caller: me,
      callee: peer,
      type: type,
    );

    if (call.status == CallStatus.busy) {
      state = CallSession(
        call: call,
        phase: CallPhase.busy,
        isCaller: true,
        errorMessage: '${peer.name} is on another call.',
      );
      return call;
    }

    state = CallSession(
      call: call,
      phase: CallPhase.calling,
      isCaller: true,
      speakerOn: true,
    );

    _listenToCallDoc(call.id);
    _armRingTimeout(call.id);

    // Do not join Agora or heartbeat while the call is still ringing.
    // The caller joins only after the callee accepts the call.
    return call;
  }

  /// Bind the incoming call locally so the in-call screen can open
  /// before Firestore flips the document off `ringing`.
  void prepareAccept(CallModel call) {
    state = CallSession(
      call: call,
      phase: CallPhase.ringing,
      isCaller: false,
      speakerOn: true,
    );
  }

  Future<void> acceptIncoming(CallModel call, UserModel me) async {
    await _assertOnline();
    if (!AppConfig.isAgoraConfigured) {
      throw StateError('Agora is not configured. Add AGORA_APP_ID.');
    }
    if (state.call?.id != call.id) {
      prepareAccept(call);
    }
    await _calling.accept(call.id);
    _listenToCallDoc(call.id);
    _startAliveHeartbeat(call.id);
    await _joinMedia(call, me.uid);
  }

  Future<void> rejectIncoming(CallModel call) async {
    await _calling.reject(call.id);
    state = CallSession(
      call: call.copyWith(status: CallStatus.rejected),
      phase: CallPhase.rejected,
      isCaller: false,
    );
  }

  Future<void> hangUp() async {
    final call = state.call;
    if (call == null) return;
    final seconds = state.duration.inSeconds;
    if (state.phase == CallPhase.calling || state.phase == CallPhase.ringing) {
      if (state.isCaller) {
        await _calling.cancel(call.id);
        state = state.copyWith(phase: CallPhase.cancelled);
      } else {
        await _calling.reject(call.id);
        state = state.copyWith(phase: CallPhase.rejected);
      }
    } else {
      await _calling.endCall(call.id, durationSeconds: seconds);
      state = state.copyWith(phase: CallPhase.ended);
    }
    _ringTimer?.cancel();
    _ringTimer = null;
    await _tearDownMedia();
  }

  Future<void> toggleMute() async {
    final next = !state.muted;
    await _calling.muteLocalAudio(next);
    state = state.copyWith(muted: next);
  }

  Future<void> toggleSpeaker() async {
    final next = !state.speakerOn;
    await _calling.setSpeakerphone(next);
    state = state.copyWith(speakerOn: next);
  }

  Future<void> toggleCamera() async {
    final next = !state.cameraOff;
    await _calling.muteLocalVideo(next);
    state = state.copyWith(cameraOff: next);
  }

  Future<void> switchCamera() => _calling.switchCamera();

  void clearTerminal() {
    _cancelTimers();
    _docSub?.cancel();
    state = const CallSession();
  }

  Future<void> _joinMedia(CallModel call, String uid) async {
    if (_joined) return;
    _joined = true;
    try {
      _remoteSub?.cancel();
      _qualitySub?.cancel();
      _errorSub?.cancel();
      _remoteSub = _calling.remoteUid$.listen(_onRemoteUid);
      _qualitySub = _calling.quality$.listen((q) {
        state = state.copyWith(quality: q);
      });
      _errorSub = _calling.engineErrors$.listen((msg) async {
        final activeCall = state.call;
        if (activeCall == null || !state.isActive) return;

        await _calling.markFailed(activeCall.id);
        await _tearDownMedia();

        state = state.copyWith(
          phase: CallPhase.failed,
          errorMessage: 'Call connection failed: $msg',
        );
      });
      await _calling.joinChannel(
        channelName: call.channelName,
        firebaseUid: uid,
        video: call.isVideo,
      );
      await _calling.setSpeakerphone(state.speakerOn);
      final already = _calling.lastRemoteUid;
      if (already != null && already != 0) {
        await _onRemoteUid(already);
      }
      if (state.phase == CallPhase.calling ||
          state.phase == CallPhase.ringing) {
        state = state.copyWith(phase: CallPhase.connected);
      }
    } catch (e) {
      _joined = false;
      await _calling.markFailed(call.id);
      state = state.copyWith(
        phase: CallPhase.failed,
        errorMessage: e is StateError
            ? e.message
            : 'Could not connect the call. Check Agora config and network.',
      );
    }
  }

  Future<void> _onRemoteUid(int uid) async {
    if (uid == 0) {
      if (state.remoteUid == null) return;
      state = state.copyWith(clearRemote: true);
      if (state.phase == CallPhase.inCall && state.call != null) {
        await _calling.markDisconnected(
          state.call!.id,
          durationSeconds: state.duration.inSeconds,
        );
        await _tearDownMedia();
        state = state.copyWith(phase: CallPhase.disconnected);
      }
      return;
    }
    state = state.copyWith(
      remoteUid: uid,
      phase: CallPhase.inCall,
    );
    _startTicker();
  }

  void _listenToCallDoc(String callId) {
    _docSub?.cancel();
    _docSub = _calling.watchCall(callId).listen((call) async {
      if (call == null) return;
      state = state.copyWith(call: call);
      switch (call.status) {
        case CallStatus.ringing:
          if (state.isCaller && state.phase == CallPhase.calling) {
            state = state.copyWith(phase: CallPhase.ringing);
          }
        case CallStatus.accepted:
          if (state.isCaller &&
              (state.phase == CallPhase.calling ||
                  state.phase == CallPhase.ringing ||
                  state.phase == CallPhase.connected)) {
            _ringTimer?.cancel();
            if (state.phase != CallPhase.inCall) {
              state = state.copyWith(phase: CallPhase.connected);
            }
            _startAliveHeartbeat(call.id);
            await _joinMedia(call, call.callerId);
          }
        case CallStatus.rejected:
          _ringTimer?.cancel();
          await _tearDownMedia();
          state = state.copyWith(phase: CallPhase.rejected);
        case CallStatus.busy:
          await _tearDownMedia();
          state = state.copyWith(phase: CallPhase.busy);
        case CallStatus.missed:
          await _tearDownMedia();
          state = state.copyWith(phase: CallPhase.missed);
        case CallStatus.cancelled:
          await _tearDownMedia();
          state = state.copyWith(phase: CallPhase.cancelled);
        case CallStatus.ended:
          await _tearDownMedia();
          state = state.copyWith(phase: CallPhase.ended);
        case CallStatus.failed:
          await _tearDownMedia();
          state = state.copyWith(phase: CallPhase.failed);
        case CallStatus.disconnected:
          await _tearDownMedia();
          state = state.copyWith(phase: CallPhase.disconnected);
      }
    });
  }

  void _armRingTimeout(String callId) {
    _ringTimer?.cancel();
    _ringTimer = Timer(AppConfig.callRingTimeout, () async {
      if (state.phase == CallPhase.calling || state.phase == CallPhase.ringing) {
        await _calling.markMissed(callId);
        await _tearDownMedia();
        state = state.copyWith(
          phase: CallPhase.missed,
          errorMessage: 'No answer. The call was missed.',
        );
      }

      _ringTimer = null;
    });
  }

  void _startTicker() {
    if (_tick != null) return;
    final started = DateTime.now();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(duration: DateTime.now().difference(started));
    });
  }

  void _startAliveHeartbeat(String callId) {
    _aliveTimer?.cancel();
    _calling.touchAlive(callId);
    _aliveTimer = Timer.periodic(AppConfig.callAliveHeartbeat, (_) {
      _calling.touchAlive(callId);
    });
  }

  Future<void> _tearDownMedia() async {
    _tick?.cancel();
    _tick = null;
    _aliveTimer?.cancel();
    _aliveTimer = null;
    _remoteSub?.cancel();
    _qualitySub?.cancel();
    _errorSub?.cancel();
    _joined = false;
    await _calling.leaveChannel();
  }

  Future<void> _assertOnline() async {
    final results = await Connectivity().checkConnectivity();
    final offline = results.every((r) => r == ConnectivityResult.none);
    if (offline) {
      throw StateError('No internet connection.');
    }
  }

  void _cancelTimers() {
    _ringTimer?.cancel();
    _tick?.cancel();
    _tick = null;
    _aliveTimer?.cancel();
    _aliveTimer = null;
  }

  @override
  void dispose() {
    _cancelTimers();
    _docSub?.cancel();
    _remoteSub?.cancel();
    _qualitySub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }
}
