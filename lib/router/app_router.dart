import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/call/audio_call_screen.dart';
import '../screens/call/incoming_call_screen.dart';
import '../screens/call/video_call_screen.dart';
import '../screens/contacts/contacts_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/home_shell.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../providers/providers.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _GoRouterRefresh();
  ref.onDispose(refresh.dispose);
  ref.listen(authStateProvider, (_, __) => refresh.tick());

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      if (auth.isLoading) return null;
      final signedIn = auth.valueOrNull != null;
      final loc = state.matchedLocation;
      final onSplash = loc == '/splash';
      final onAuth = loc == '/login' || loc == '/register';
      if (onSplash) return null;
      if (!signedIn && !onAuth) return '/login';
      if (signedIn && onAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/call/audio',
        builder: (_, __) => const AudioCallScreen(),
      ),
      GoRoute(
        path: '/call/video',
        builder: (_, __) => const VideoCallScreen(),
      ),
      GoRoute(
        path: '/call/incoming',
        builder: (_, __) => const IncomingCallScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/contacts',
                builder: (_, __) => const ContactsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/calls', builder: (_, __) => const HistoryScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _GoRouterRefresh extends ChangeNotifier {
  void tick() => notifyListeners();
}
