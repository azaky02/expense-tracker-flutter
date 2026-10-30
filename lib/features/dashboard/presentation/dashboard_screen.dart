import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/ds_tokens.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../accounts/presentation/account_widgets.dart';
import '../../budgets/data/budget_repository.dart';
import '../../budgets/presentation/budget_providers.dart';
import '../../payment_methods/presentation/payment_method_providers.dart';
import '../../people/data/ledger_repository.dart';
import '../../people/presentation/people_providers.dart';
import '../../people/presentation/people_screen.dart';
import '../../transactions/data/transaction_models.dart';
import '../../transactions/presentation/transaction_providers.dart';
import 'home_widgets.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../core/settings/settings_state.dart';

/// Month shown on the dashboard (first day of that month).
final dashboardMonthProvider = NotifierProvider<MonthNotifier, DateTime>(MonthNotifier.new);

/// Selected month (first day). Shared shape for dashboard, budgets and reports.
class MonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void set(DateTime month) => state = DateTime(month.year, month.month);
}

/// Home (UI/UX document §6): header → balance card → alerts → accounts → people balances →
/// spending by category → recent transactions.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(dashboardMonthProvider);
    final range = getMonthRange(month);
    final summary = ref.watch(monthSummaryProvider(range)).value;
    final breakdown = ref.watch(expenseCategoryBreakdownProvider(range)).value ?? const <CategoryBreakdownItem>[];
    final recent = ref.watch(recentTransactionsProvider(6));
    final accounts = ref.watch(accountsProvider).value ?? const <AccountWithBalance>[];
    final total = ref.watch(totalBalanceProvider);
    final people = (ref.watch(peopleWithBalancesProvider).value ?? const <PersonWithBalance>[])
        .where((p) => p.balance.net != 0)
        .take(4)
        .toList();
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final income = summary?.income ?? 0;
    final expense = summary?.expense ?? 0;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(recentTransactionsProvider(6)),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HomeHeader(total: total),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const HomeActions(),
                  SectionHeader('home.thisMonth'.tr(), action: 'home.allDetails'.tr(), onAction: () => context.push('/stats')),
                  MonthSummaryRow(income: income, expense: expense),
                  const SizedBox(height: 12),
                  const _Alerts(),
                  SectionHeader(
                    'dashboard.recentTransactions'.tr(),
                    action: 'common.viewAll'.tr(),
                    onAction: () => context.go('/transactions'),
                  ),
                  recent.when(
                    loading: () => const SkeletonList(count: 3),
                    error: (e, _) =>
                        ErrorState(message: 'common.loadError'.tr(), onRetry: () => ref.invalidate(recentTransactionsProvider(6))),
                    data: (items) => items.isEmpty
                        ? AppCard(
                            child: EmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'dashboard.noTransactions'.tr(),
                              actionLabel: 'add.expense'.tr(),
                              onAction: () => context.push('/transactions/add'),
                            ),
                          )
                        : AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Column(
                              children: [
                                for (var i = 0; i < items.length; i++) ...[
                                  if (i > 0) const Divider(height: 1),
                                  HomeTransactionRow(
                                    item: items[i],
                                    onTap: () => context.push('/transactions/${items[i].transaction.id}/edit'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                  if (accounts.isNotEmpty && settings.moduleShown(AppModule.accounts.key)) ...[
                    SectionHeader('dashboard.accounts'.tr(), action: 'common.viewAll'.tr(), onAction: () => context.push('/accounts')),
                    SizedBox(
                      height: 104,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: accounts.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, i) => _AccountChip(accounts[i]),
                      ),
                    ),
                  ],
                  if (people.isNotEmpty && settings.moduleShown(AppModule.custody.key)) ...[
                    SectionHeader('dashboard.people'.tr(), action: 'common.viewAll'.tr(), onAction: () => context.go('/people')),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.9,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: [for (final p in people) _PersonChip(p)],
                    ),
                  ],
                  SectionHeader(
                    'dashboard.spendingThisMonth'.tr(),
                    action: 'dashboard.reports'.tr(),
                    onAction: () => context.push('/reports'),
                  ),
                  if (breakdown.isEmpty)
                    AppCard(
                      child: Text('dashboard.noSpending'.tr(), style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    )
                  else
                    AppCard(child: _SpendingBars(items: breakdown.take(5).toList())),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pending confirmations, budget warnings and near card due dates (UX §6 "alerts").
class _Alerts extends ConsumerWidget {
  const _Alerts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingIncomingProvider).value ?? 0;
    final now = DateTime.now();
    final budgets =
        (ref.watch(budgetsForMonthProvider(budgetCycleMonthOf(now, ref.watch(settingsProvider.select((s) => s.salaryDay))))).value ??
                const <BudgetStatus>[])
            .where((b) => b.level != BudgetLevel.ok)
            .toList();
    final cards = ref.watch(activeCardsProvider).value ?? const [];
    final due = <(String, int)>[];
    for (final c in cards) {
      if (c.card.dueDateDay == null) continue;
      final days = daysUntilNextDueDate(c.card.dueDateDay!);
      if (days <= 7) due.add((c.card.nickname, days));
    }
    final items = <Widget>[
      if (pending > 0)
        _AlertTile(
          icon: Icons.mark_email_unread_outlined,
          color: DS.warning,
          text: 'dashboard.pendingConfirmations'.tr(namedArgs: {'count': '$pending'}),
          onTap: () => context.push('/notifications'),
        ),
      for (final b in budgets)
        _AlertTile(
          icon: Icons.pie_chart_outline,
          color: b.level == BudgetLevel.warning ? DS.warning : DS.danger,
          text: 'budgets.alert.${b.level.name}'.tr(namedArgs: {'category': b.category.name, 'percent': '${(b.ratio * 100).round()}'}),
          onTap: () => context.push('/budgets'),
        ),
      for (final d in due)
        _AlertTile(
          icon: Icons.credit_card,
          color: DS.primary,
          text: 'dashboard.dueSoonAlert'.tr(namedArgs: {'cardName': d.$1, 'days': '${d.$2}'}),
          onTap: () => context.push('/accounts'),
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    items.removeRange(items.length > 3 ? 3 : items.length, items.length);
    return Column(
      children: [for (final w in items) Padding(padding: const EdgeInsets.only(bottom: 8), child: w)],
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.icon, required this.color, required this.text, this.onTap});
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: color.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
          Icon(Icons.arrow_forward_ios, color: color, size: 14),
        ],
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip(this.a);
  final AccountWithBalance a;

  @override
  Widget build(BuildContext context) {
    final negative = a.balance < 0;
    return SizedBox(
      width: 140,
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: () => context.push('/accounts/${a.account.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AccountBubble(a, size: 30),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(a.account.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge),
                ),
              ],
            ),
            AmountText(a.balance, size: 16, color: negative ? Theme.of(context).colorScheme.error : null),
          ],
        ),
      ),
    );
  }
}

class _PersonChip extends StatelessWidget {
  const _PersonChip(this.p);
  final PersonWithBalance p;

  @override
  Widget build(BuildContext context) {
    final net = p.balance.net;
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/people/${p.person.id}'),
      child: Row(
        children: [
          IconBubble(icon: Icons.person_outline, color: netColor(context, net), size: 36),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(p.person.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
                Text(netLabel(context, net), style: Theme.of(context).textTheme.bodySmall),
                AmountText(net.abs(), size: 13, color: netColor(context, net)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpendingBars extends StatelessWidget {
  const _SpendingBars({required this.items});
  final List<CategoryBreakdownItem> items;

  @override
  Widget build(BuildContext context) {
    final max = items.fold<double>(0, (m, i) => i.total > m ? i.total : m);
    return Column(
      children: [
        for (final i in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: colorFromHex(i.categoryColor), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 84, child: Text(i.categoryName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: max == 0 ? 0 : i.total / max, minHeight: 8, color: colorFromHex(i.categoryColor)),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 78,
                  child: Align(alignment: AlignmentDirectional.centerEnd, child: AmountText(i.total, size: 12)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
