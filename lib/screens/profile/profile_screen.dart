import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/error_mapper.dart';
import '../../core/utils/validators.dart';
import '../../providers/providers.dart';
import '../../widgets/common_button.dart';
import '../../widgets/status_view.dart';
import '../../widgets/user_tile.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editing = false;
  bool _busy = false;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _photo = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _photo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncUser = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(presenceClockProvider);

    return asyncUser.when(
      loading: () => const StatusView.loading(),
      error: (e, _) => StatusView.error(message: e.toString()),
      data: (user) {
        if (user == null) return const StatusView.loading();
        if (_name.text.isEmpty && !_editing) {
          _name.text = user.name;
          _phone.text = user.phone ?? '';
          _photo.text = user.photoUrl ?? '';
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: UserAvatar(user: user, radius: 44)),
            const SizedBox(height: 12),
            Center(
              child: Text(
                user.name,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Center(child: Text(user.email)),
            if (user.phone != null && user.phone!.isNotEmpty)
              Center(child: Text(user.phone!)),
            const SizedBox(height: 8),
            Center(
              child: Chip(
                avatar: Icon(
                  Icons.circle,
                  size: 10,
                  color: user.isOnline ? AppColors.online : AppColors.offline,
                ),
                label: Text(user.isOnline ? 'Online' : 'Offline'),
              ),
            ),
            const SizedBox(height: 16),
            if (_editing) ...[
              TextFormField(
                controller: _name,
                validator: Validators.name,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _photo,
                decoration: const InputDecoration(
                  labelText: 'Photo URL (optional)',
                ),
              ),
              const SizedBox(height: 16),
              CommonButton(
                label: 'Save',
                loading: _busy,
                onPressed: () async {
                  setState(() => _busy = true);
                  try {
                    await ref.read(userServiceProvider).updateProfile(
                          uid: user.uid,
                          name: _name.text,
                          phone: _phone.text,
                          photoUrl: _photo.text,
                        );
                    setState(() => _editing = false);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(ErrorMapper.generic(e))),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => setState(() => _editing = false),
                child: const Text('Cancel'),
              ),
            ] else
              CommonButton(
                label: 'Edit Profile',
                icon: Icons.edit,
                onPressed: () => setState(() => _editing = true),
              ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Appearance'),
              subtitle: Text(switch (themeMode) {
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
                ThemeMode.system => 'System',
              }),
              onTap: () => ref.read(themeModeProvider.notifier).cycle(),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authServiceProvider).logout();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}
