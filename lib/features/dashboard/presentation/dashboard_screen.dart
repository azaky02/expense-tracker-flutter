import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/settings_provider.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../accounts/presentation/account_widgets.dart';
import '../../budgets/data/budget_repository.dart';
import '../../cars/presentation/cars_screens.dart';
import '../../budgets/presentation/budget_providers.dart';
import '../../payment_methods/presentation/payment_method_providers.dart';
import '../../people/data/ledger_repository.dart';
import '../../people/presentation/people_providers.dart';
import '../../people/presentation/people_screen.dart';
import '../../transactions/data/transaction_models.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';

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
    final income = summary?.income ?? 0;
    final expense = summary?.expense ?? 0;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(recentTransactionsProvider(6)),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(month: month),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: _BalanceCard(total: total, income: income, expense: expense),
                  ),
                  Transform.translate(offset: const Offset(0, -14), child: const _MainActions()),
                  const _Shortcuts(),
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Column(
                              children: [
                                for (final t in items)
                                  TransactionTile(
                                    item: t,
                                    showDate: true,
                                    onTap: () => context.push('/transactions/${t.transaction.id}/edit'),
                                  ),
                              ],
                            ),
                          ),
                  ),
                  if (accounts.isNotEmpty) ...[
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
                  if (people.isNotEmpty) ...[
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

class _Header extends ConsumerWidget {
  const _Header({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final greeting = settings.userName.isNotEmpty
        ? 'dashboard.greeting'.tr(namedArgs: {'name': settings.userName})
        : 'dashboard.greetingGeneric'.tr();
    return Container(
      decoration: const BoxDecoration(
        gradient: DS.navyGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 8, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('app.name'.tr(), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                    Text(greeting, style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const IconTheme(
                data: IconThemeData(color: Colors.white),
                child: SyncStatusBadge(),
              ),
              const IconTheme(
                data: IconThemeData(color: Colors.white),
                child: NotificationsBell(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(24)),
              child: MonthSelector(month: month, light: true, onChanged: (m) => ref.read(dashboardMonthProvider.notifier).set(m)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.total, required this.income, required this.expense});
  final double total;
  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    final net = income - expense;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: DS.heroGradient,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        border: Border.all(color: DS.gold.withValues(alpha: 0.35)),
        boxShadow: const [BoxShadow(color: Color(0x330A3B28), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'dashboard.totalBalance'.tr(),
            style: const TextStyle(color: DS.goldLight, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          AmountText(total, color: Colors.white, size: 30, weight: FontWeight.w800),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Mini(label: 'dashboard.income'.tr(), amount: income, color: DS.success, icon: Icons.south_west),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Mini(label: 'dashboard.expenses'.tr(), amount: expense, color: DS.danger, icon: Icons.north_east),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${'dashboard.netFlow'.tr()}: ', style: const TextStyle(color: Colors.white70)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: (net >= 0 ? const Color(0xFF4ADE80) : const Color(0xFFF87171)).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AmountText(net, color: net >= 0 ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5), size: 14, signed: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.amount, required this.color, required this.icon});
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      // Light: white boxes on the green card. Dark: translucent, so the card stays calm.
      decoration: BoxDecoration(
        color: dark ? Colors.black.withValues(alpha: 0.25) : Colors.white,
        borderRadius: BorderRadius.circular(DS.radius),
        border: dark ? Border.all(color: Colors.white.withValues(alpha: 0.08)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: dark ? Colors.white70 : DS.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 2),
          AmountText(amount, color: dark ? Colors.white : DS.text, size: 17),
        ],
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
    final budgets = (ref.watch(budgetsForMonthProvider(DateTime(now.year, now.month))).value ?? const <BudgetStatus>[])
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

/// The three most used actions, right under the balance card.
class _MainActions extends ConsumerWidget {
  const _MainActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    Widget action(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(DS.radius),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(DS.radius),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DS.radius),
              border: Border.all(color: scheme.outline),
              boxShadow: DS.softShadow(Theme.of(context).brightness),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 6),
                Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
    return Row(
      children: [
        action(Icons.remove_rounded, 'add.expense'.tr(), scheme.error, () => context.push('/transactions/add')),
        const SizedBox(width: 10),
        action(Icons.add_rounded, 'add.income'.tr(), scheme.secondary, () => context.push('/transactions/add?type=income')),
        const SizedBox(width: 10),
        action(Icons.local_gas_station_rounded, 'home.carExpense'.tr(), DS.gold, () => startCarExpense(context, ref)),
      ],
    );
  }
}

/// Every other section in one scrollable row, all in the brand colour.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final items = <(IconData, String, String)>[
      (Icons.insights_rounded, 'stats.title', '/stats'),
      (Icons.event_repeat_rounded, 'installments.title', '/installments'),
      (Icons.handshake_outlined, 'home.loan', '/ledger/new'),
      (Icons.directions_car_filled_outlined, 'home.myCars', '/cars'),
      (Icons.account_balance_wallet_outlined, 'accounts.title', '/accounts'),
      (Icons.pie_chart_outline_rounded, 'home.budgets', '/budgets'),
      (Icons.bar_chart_rounded, 'reports.title', '/reports'),
      (Icons.swap_horiz_rounded, 'add.transfer', '/transactions/add?type=transfer'),
    ];
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, i) {
          final (icon, label, route) = items[i];
          return InkWell(
            borderRadius: BorderRadius.circular(DS.radius),
            onTap: () => context.push(route),
            child: SizedBox(
              width: 74,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: DS.gold.withValues(alpha: 0.35)),
                    ),
                    child: Icon(icon, color: color, size: 23),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
