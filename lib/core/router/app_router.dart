import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/clients/presentation/add_edit_client_screen.dart';
import '../../features/clients/presentation/client_detail_screen.dart';
import '../../features/clients/presentation/clients_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/more/presentation/more_screen.dart';
import '../../features/pnl/presentation/pnl_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import 'app_shell.dart';
import 'go_router_refresh_stream.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authRepo.onAuthStateChange),
    redirect: (context, state) => _redirect(authRepo, state),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      // Full-screen forms (no bottom tab bar), matching the design's
      // showTabs:false treatment of the add-client screen. Declared before
      // the shell so these literal paths win over the shell's '/clients/:id'
      // dynamic segment.
      GoRoute(
        path: '/clients/new',
        builder: (context, state) => const AddEditClientScreen(),
      ),
      GoRoute(
        path: '/clients/:id/edit',
        builder: (context, state) =>
            AddEditClientScreen(clientId: state.pathParameters['id']),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/clients',
                builder: (context, state) => const ClientsScreen(),
                routes: [
                  // Detail keeps the tab bar visible (design: showTabs is
                  // true for the client screen), so it stays nested here.
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ClientDetailScreen(
                      clientId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pnl',
                builder: (context, state) => const PnlScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

String? _redirect(AuthRepository authRepo, GoRouterState state) {
  // The splash screen decides its own next step once its minimum display
  // time elapses — never redirect away from it early.
  if (state.matchedLocation == '/splash') return null;

  final loggedIn = authRepo.currentUser != null;
  final goingToAuth =
      state.matchedLocation == '/login' || state.matchedLocation == '/signup';

  if (!loggedIn && !goingToAuth) return '/login';
  if (loggedIn && goingToAuth) return '/home';
  return null;
}
