import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/call_model.dart';
import '../../providers/providers.dart';
import '../../widgets/status_view.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final history = ref.watch(callHistoryProvider);

    return history.when(
      loading: () => const StatusView.loading(),
      error: (e, _) => StatusView.error(
        message: 'Could not load call history.',
        retry: () => ref.invalidate(callHistoryProvider),
      ),
      data: (calls) {
        if (me == null) return const StatusView.loading();
        if (calls.isEmpty) {
          return const StatusView.empty(
            message: 'No calls yet. Start one from Contacts.',
            icon: Icons.call_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: calls.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final call = calls[i];
            final incoming = call.isIncomingFor(me.uid);
            final missed = call.status == CallStatus.missed ||
                (incoming && call.status == CallStatus.rejected);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: (missed ? AppColors.decline : AppColors.primary)
                    .withValues(alpha: 0.12),
                child: Icon(
                  call.isVideo ? Icons.videocam : Icons.call,
                  color: missed ? AppColors.decline : AppColors.primary,
                ),
              ),
              title: Text(
                call.peerName(me.uid),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: missed ? AppColors.decline : null,
                ),
              ),
              subtitle: Text(
                [
                  incoming ? 'Incoming' : 'Outgoing',
                  call.isVideo ? 'Video' : 'Audio',
                  call.status.name,
                  if (call.durationSeconds > 0)
                    formatCallDuration(Duration(seconds: call.durationSeconds)),
                ].join(' · '),
              ),
              trailing: Text(
                call.createdAt == null ? '' : formatCallWhen(call.createdAt!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          },
        );
      },
    );
  }
}
