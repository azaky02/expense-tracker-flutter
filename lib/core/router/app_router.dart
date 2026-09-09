import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/lock/presentation/unlock_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/payment_methods/presentation/payment_methods_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/transactions/presentation/add_transaction_screen.dart';
import '../../features/transactions/presentation/transactions_list_screen.dart';
import '../security/lock_provider.dart';
import '../settings/settings_provider.dart';
import 'scaffold_with_nav_bar.dart';

/// Bridges a Riverpod Ref's changes into a Listenable go_router can use for `refreshListenable`,
/// so lock/onboarding state changes re-run `redirect` without needing per-screen guards.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(lockProvider, (_, _) => notifyListeners());
    ref.listen(settingsProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final settings = ref.read(settingsProvider);
      final isUnlocked = ref.read(lockProvider);
      final goingToOnboarding = state.matchedLocation == '/onboarding';
      final goingToUnlock = state.matchedLocation == '/unlock';

      if (!settings.hasOnboarded) {
        return goingToOnboarding ? null : '/onboarding';
      }
      if (settings.appLockEnabled && !isUnlocked) {
        return goingToUnlock ? null : '/unlock';
      }
      if (goingToOnboarding || goingToUnlock) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/unlock', builder: (context, state) => const UnlockScreen()),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/transactions/add',
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: AddTransactionScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (context, state) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/transactions',
              builder: (context, state) => const TransactionsListScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/cards', builder: (context, state) => const PaymentMethodsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          ]),
        ],
      ),
    ],
  );
});
