import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/call_model.dart';
import '../../providers/providers.dart';
import '../../widgets/call_controls.dart';
import '../../widgets/user_tile.dart';
import '../../models/user_model.dart';

class AudioCallScreen extends ConsumerWidget {
  const AudioCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(callControllerProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;
    final call = session.call;

    if (call == null || me == null) {
      return const Scaffold(body: Center(child: Text('No active call')));
    }

    final peer = UserModel(
      uid: call.peerId(me.uid),
      name: call.peerName(me.uid),
      email: '',
      photoUrl: call.peerPhoto(me.uid),
      isOnline: true,
    );

    final terminal = !session.isActive && session.phase != CallPhase.idle;

    return PopScope(
      canPop: terminal,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(callControllerProvider.notifier).clearTerminal();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    NetworkQualityChip(quality: session.quality),
                    const Spacer(),
                    Text(
                      phaseLabel(session.phase),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                const Spacer(),
                UserAvatar(user: peer, radius: 56),
                const SizedBox(height: 16),
                Text(
                  peer.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  session.phase == CallPhase.inCall
                      ? formatCallDuration(session.duration)
                      : phaseLabel(session.phase),
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                if (session.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    session.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFFCA5A5)),
                  ),
                ],
                const Spacer(),
                if (session.phase == CallPhase.calling ||
                    session.phase == CallPhase.ringing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                if (terminal)
                  FilledButton(
                    onPressed: () {
                      ref.read(callControllerProvider.notifier).clearTerminal();
                      context.go('/home');
                    },
                    child: const Text('Done'),
                  )
                else
                  CallControlBar(
                    session: session,
                    video: false,
                    onMute: () =>
                        ref.read(callControllerProvider.notifier).toggleMute(),
                    onSpeaker: () =>
                        ref.read(callControllerProvider.notifier).toggleSpeaker(),
                    onCamera: () {},
                    onSwitchCamera: () {},
                    onEnd: () =>
                        ref.read(callControllerProvider.notifier).hangUp(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
