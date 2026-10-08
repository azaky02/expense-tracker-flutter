import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/auth/presentation/auth_screens.dart';
import '../../features/budgets/presentation/budgets_screen.dart';
import '../../features/categories/presentation/category_management_screen.dart';
import '../../features/transactions/presentation/transaction_filters_screen.dart';
import '../../features/people/presentation/ledger_entry_form_screen.dart';
import '../../features/people/presentation/notifications_screen.dart';
import '../../features/people/presentation/people_screen.dart';
import '../../features/people/presentation/person_form_screen.dart';
import '../../features/people/presentation/person_screen.dart';
import '../../features/people/presentation/statement_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/lock/presentation/unlock_screen.dart';
import '../../features/payment_methods/presentation/add_card_screen.dart';
import '../../features/payment_methods/presentation/card_details_screen.dart';
import '../../features/payment_methods/presentation/edit_card_screen.dart';
import '../../features/payment_methods/presentation/payment_methods_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/account_sync_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/transactions/presentation/add_transaction_screen.dart';
import '../../features/transactions/presentation/edit_transaction_screen.dart';
import '../../features/transactions/presentation/transactions_list_screen.dart';
import '../db/tables.dart';
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
      // Welcome, sign-in and registration are all reachable before onboarding is complete.
      final goingToOnboarding = const {'/onboarding', '/login', '/register'}.contains(state.matchedLocation);
      final goingToUnlock = state.matchedLocation == '/unlock';

      if (!settings.hasOnboarded) {
        return goingToOnboarding ? null : '/onboarding';
      }
      if (settings.appLockEnabled && !isUnlocked) {
        return goingToUnlock ? null : '/unlock';
      }
      // Login/register stay reachable later (e.g. from More); only the welcome page is one-time.
      if (state.matchedLocation == '/onboarding' || goingToUnlock) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/unlock', builder: (context, state) => const UnlockScreen()),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/transactions/add',
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: AddTransactionScreen(
            type: switch (state.uri.queryParameters['type']) {
              'income' => TransactionType.income,
              'transfer' => TransactionType.transfer,
              _ => TransactionType.expense,
            },
          ),
        ),
      ),
      GoRoute(
        path: '/transactions/:id/edit',
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: EditTransactionScreen(
            transactionId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ),
      GoRoute(
        path: '/cards/add',
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: AddCardScreen(),
        ),
      ),
      GoRoute(
        path: '/cards/:id',
        builder: (context, state) => CardDetailsScreen(
          cardId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/cards/:id/edit',
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: EditCardScreen(
            cardId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ),
      GoRoute(
        path: '/cards',
        builder: (context, state) => const PaymentMethodsScreen(),
      ),
      GoRoute(path: '/accounts', builder: (context, state) => const AccountsScreen()),
      GoRoute(
        path: '/accounts/new',
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: AccountFormScreen(
            type: AccountType.values.firstWhere((t) => t.name == state.uri.queryParameters['type'], orElse: () => AccountType.bank),
          ),
        ),
      ),
      GoRoute(
        path: '/accounts/:id',
        builder: (context, state) => AccountDetailsScreen(accountId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/accounts/:id/edit',
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: AccountFormScreen(accountId: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(path: '/budgets', builder: (context, state) => const BudgetsScreen()),
      GoRoute(
        path: '/transactions/filters',
        pageBuilder: (context, state) => const MaterialPage(fullscreenDialog: true, child: TransactionFiltersScreen()),
      ),
      GoRoute(
        path: '/ledger/new',
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: LedgerEntryFormScreen(
            personId: int.tryParse(state.uri.queryParameters['personId'] ?? ''),
            settlement: state.uri.queryParameters['kind'] == 'settlement',
          ),
        ),
      ),
      GoRoute(
        path: '/people/new',
        pageBuilder: (context, state) => const MaterialPage(fullscreenDialog: true, child: PersonFormScreen()),
      ),
      GoRoute(
        path: '/people/:id',
        builder: (context, state) => PersonScreen(personId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/people/:id/edit',
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: PersonFormScreen(personId: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '/people/:id/statement',
        builder: (context, state) => StatementScreen(personId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountSyncScreen(),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoryManagementScreen(),
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
            GoRoute(path: '/people', builder: (context, state) => const PeopleScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          ]),
        ],
      ),
    ],
  );
});
