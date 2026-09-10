import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../../widgets/status_view.dart';
import '../../widgets/user_tile.dart';
import '../home/home_screen.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(presenceClockProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;
    final asyncContacts = ref.watch(contactsProvider);
    final query = ref.watch(searchQueryProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) =>
                ref.read(searchQueryProvider.notifier).state = v,
            decoration: const InputDecoration(
              hintText: 'Search by name',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: asyncContacts.when(
            loading: () => const StatusView.loading(),
            error: (e, _) => StatusView.error(
              message: 'Could not load contacts. Check your connection.',
              retry: () => ref.invalidate(contactsProvider),
            ),
            data: (users) {
              final list = query.trim().isEmpty
                  ? users
                  : ref.watch(filteredContactsProvider);
              if (list.isEmpty) {
                return const StatusView.empty(
                  message: 'No people found.',
                );
              }
              if (me == null) return const StatusView.loading();
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final peer = list[i];
                  return UserTile(
                    user: peer,
                    onLongPress: () => _blockUser(context, ref, me.uid, peer),
                    onAudio: () => startOutgoingCall(
                      context,
                      ref,
                      me,
                      peer,
                      CallType.audio,
                    ),
                    onVideo: () => startOutgoingCall(
                      context,
                      ref,
                      me,
                      peer,
                      CallType.video,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

Future<void> _blockUser(
  BuildContext context,
  WidgetRef ref,
  String uid,
  UserModel peer,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Block ${peer.name}?'),
      content: const Text(
        'They will disappear from your contact list until you unblock them.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await ref.read(userServiceProvider).toggleBlock(
        uid: uid,
        otherUid: peer.uid,
        block: true,
      );
}
