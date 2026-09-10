import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/permission_helper.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../../widgets/user_tile.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.vibrate();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(incomingCallProvider, (prev, next) {
      final had = prev?.asData?.value != null;
      final has = next.valueOrNull != null;
      if (had && !has && context.mounted) {
        final session = ref.read(callControllerProvider);
        if (session.isActive) return;
        context.go('/home');
      }
    });

    final incoming = ref.watch(incomingCallProvider).valueOrNull;
    final sessionCall = ref.watch(callControllerProvider).call;
    final call = incoming ??
        (sessionCall != null && sessionCall.status == CallStatus.ringing
            ? sessionCall
            : null);
    final me = ref.watch(currentUserProvider).valueOrNull;

    if (call == null || me == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Call is no longer available'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    final caller = UserModel(
      uid: call.callerId,
      name: call.callerName,
      email: '',
      photoUrl: call.callerPhoto,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Text(
                call.isVideo ? 'Incoming Video Call' : 'Incoming Audio Call',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const Spacer(),
              UserAvatar(user: caller, radius: 56),
              const SizedBox(height: 16),
              Text(
                caller.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ringing…',
                style: TextStyle(color: Colors.white70),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Action(
                    color: AppColors.decline,
                    icon: Icons.call_end,
                    label: 'Decline',
                    onTap: () async {
                      await ref
                          .read(callControllerProvider.notifier)
                          .rejectIncoming(call);
                      if (context.mounted) context.go('/home');
                    },
                  ),
                  _Action(
                    color: AppColors.accept,
                    icon: Icons.call,
                    label: 'Accept',
                    onTap: () async {
                      final perm = await PermissionHelper.ensureCall(
                        video: call.isVideo,
                      );
                      if (!context.mounted) return;
                      if (perm != PermissionOutcome.granted) {
                        await PermissionHelper.showDeniedDialog(
                          context,
                          permanentlyDenied:
                              perm == PermissionOutcome.permanentlyDenied,
                          message: call.isVideo
                              ? 'Camera and microphone are required to accept this video call.'
                              : 'Microphone is required to accept this call.',
                        );
                        return;
                      }
                      try {
                        final controller =
                            ref.read(callControllerProvider.notifier);
                        controller.prepareAccept(call);
                        if (!context.mounted) return;
                        context.go(
                          call.isVideo ? '/call/video' : '/call/audio',
                        );
                        await controller.acceptIncoming(call, me);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString().replaceFirst('Bad state: ', ''),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: CircleAvatar(
            radius: 34,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
