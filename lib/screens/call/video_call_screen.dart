import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/call_model.dart';
import '../../providers/providers.dart';
import '../../widgets/call_controls.dart';

class VideoCallScreen extends ConsumerWidget {
  const VideoCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(callControllerProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;
    final engine = ref.watch(callingServiceProvider).engine;
    final call = session.call;

    if (call == null || me == null) {
      return const Scaffold(body: Center(child: Text('No active call')));
    }

    final terminal = !session.isActive && session.phase != CallPhase.idle;
    final peerName = call.peerName(me.uid);

    return PopScope(
      canPop: terminal,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(callControllerProvider.notifier).clearTerminal();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: session.remoteUid != null && engine != null
                  ? AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: engine,
                        canvas: VideoCanvas(uid: session.remoteUid),
                        connection: RtcConnection(channelId: call.channelName),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF0F172A),
                      child: Center(
                        child: Text(
                          phaseLabel(session.phase),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 48,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 110,
                  height: 160,
                  child: engine == null || session.cameraOff
                      ? Container(
                          color: Colors.black54,
                          child: const Icon(Icons.videocam_off, color: Colors.white),
                        )
                      : AgoraVideoView(
                          controller: VideoViewController(
                            rtcEngine: engine,
                            canvas: const VideoCanvas(uid: 0),
                          ),
                        ),
                ),
              ),
            ),
            Positioned(
              top: 48,
              left: 16,
              right: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    session.phase == CallPhase.inCall
                        ? formatCallDuration(session.duration)
                        : phaseLabel(session.phase),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  NetworkQualityChip(quality: session.quality),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: terminal
                  ? FilledButton(
                      onPressed: () {
                        ref.read(callControllerProvider.notifier).clearTerminal();
                        context.go('/home');
                      },
                      child: const Text('Done'),
                    )
                  : CallControlBar(
                      session: session,
                      video: true,
                      onMute: () =>
                          ref.read(callControllerProvider.notifier).toggleMute(),
                      onSpeaker: () => ref
                          .read(callControllerProvider.notifier)
                          .toggleSpeaker(),
                      onCamera: () =>
                          ref.read(callControllerProvider.notifier).toggleCamera(),
                      onSwitchCamera: () =>
                          ref.read(callControllerProvider.notifier).switchCamera(),
                      onEnd: () =>
                          ref.read(callControllerProvider.notifier).hangUp(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
