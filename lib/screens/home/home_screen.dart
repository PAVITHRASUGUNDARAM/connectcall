import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/permission_helper.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../../widgets/status_view.dart';
import '../../widgets/user_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final contacts = ref.watch(filteredContactsProvider);
    final history = ref.watch(callHistoryProvider);
    final query = ref.watch(searchQueryProvider);
    ref.watch(presenceClockProvider);

    return me.when(
      loading: () => const StatusView.loading(),
      error: (e, _) => StatusView.error(message: e.toString()),
      data: (user) {
        if (user == null) {
          return const StatusView.loading(message: 'Loading profile...');
        }
        final recentPeers = _recentPeers(history.valueOrNull ?? [], user.uid);
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    UserAvatar(user: user, radius: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hi, ${user.name}',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            user.isOnline ? 'You are online' : 'Offline',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  onChanged: (v) =>
                      ref.read(searchQueryProvider.notifier).state = v,
                  decoration: const InputDecoration(
                    hintText: 'Search contacts',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
            ),
            if (query.isEmpty && recentPeers.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Text(
                    'Recent',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
            if (query.isEmpty && recentPeers.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 96,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, i) {
                      final peer = recentPeers[i];
                      return Column(
                        children: [
                          UserAvatar(user: peer),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 72,
                            child: Text(
                              peer.name,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemCount: recentPeers.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  query.isEmpty ? 'People' : 'Results',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ),
            if (contacts.isEmpty)
              const SliverFillRemaining(
                child: StatusView.empty(
                  message: 'No contacts yet. Register a second account to call.',
                ),
              )
            else
              SliverList.builder(
                itemCount: contacts.length,
                itemBuilder: (context, i) {
                  final peer = contacts[i];
                  return UserTile(
                    user: peer,
                    onAudio: () => startOutgoingCall(
                      context,
                      ref,
                      user,
                      peer,
                      CallType.audio,
                    ),
                    onVideo: () => startOutgoingCall(
                      context,
                      ref,
                      user,
                      peer,
                      CallType.video,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  List<UserModel> _recentPeers(List<CallModel> calls, String uid) {
    final seen = <String>{};
    final result = <UserModel>[];
    for (final call in calls) {
      final peerId = call.peerId(uid);
      if (!seen.add(peerId)) continue;
      result.add(
        UserModel(
          uid: peerId,
          name: call.peerName(uid),
          email: '',
          photoUrl: call.peerPhoto(uid),
          isOnline: false,
        ),
      );
      if (result.length >= 8) break;
    }
    return result;
  }
}

Future<void> startOutgoingCall(
  BuildContext context,
  WidgetRef ref,
  UserModel me,
  UserModel peer,
  CallType type,
) async {
  final perm = await PermissionHelper.ensureCall(video: type == CallType.video);
  if (!context.mounted) return;
  if (perm != PermissionOutcome.granted) {
    await PermissionHelper.showDeniedDialog(
      context,
      permanentlyDenied: perm == PermissionOutcome.permanentlyDenied,
      message: type == CallType.video
          ? 'Camera and microphone are required for video calls.'
          : 'Microphone is required for audio calls.',
    );
    return;
  }
  try {
    final call = await ref.read(callControllerProvider.notifier).startCall(
          me: me,
          peer: peer,
          type: type,
        );
    if (!context.mounted) return;
    if (call.status == CallStatus.busy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${peer.name} is on another call.')),
      );
      return;
    }
    context.push(type == CallType.video ? '/call/video' : '/call/audio');
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
    );
  }
}
