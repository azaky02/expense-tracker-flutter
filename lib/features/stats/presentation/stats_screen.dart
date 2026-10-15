import 'package:drift/drift.dart' show Variable;
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/db/tables.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../cars/data/car_repository.dart';
import '../../categories/presentation/category_providers.dart';
import '../../installments/data/installment_repository.dart';
import '../../transactions/data/transaction_models.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';
import '../data/stats_period.dart';

/// Main category + its sub-categories, for the custom period's category filter.
final _categoryFamilyProvider = FutureProvider.family<Set<int>, int>((ref, mainId) async {
  final db = ref.watch(databaseProvider);
  final rows = await db
      .customSelect(
        'SELECT id FROM categories WHERE id = ? OR parent_category_id = ?',
        variables: [Variable.withInt(mainId), Variable.withInt(mainId)],
      )
      .get();
  return {for (final r in rows) r.read<int>('id')};
});

final _statsTransactionsProvider = StreamProvider<List<TransactionWithDetails>>((ref) {
  final p = ref.watch(statsPeriodProvider);
  return ref.watch(transactionRepositoryProvider).watchList(TransactionFilters(from: p.from, to: p.to));
});

/// Everything for the current period, or null while loading.
final statsDataProvider = Provider<StatsData?>((ref) {
  final p = ref.watch(statsPeriodProvider);
  final tx = ref.watch(_statsTransactionsProvider).value;
  final cars = ref.watch(carsProvider).value;
  final inst = ref.watch(installmentsProvider).value;
  final family = p.categoryId == null ? null : ref.watch(_categoryFamilyProvider(p.categoryId!)).value;
  if (tx == null || cars == null || inst == null || (p.categoryId != null && family == null)) return null;
  return StatsData(period: p, transactions: tx, cars: cars, installments: inst, categoryIds: family);
});

String _range(BuildContext context, StatsPeriod p) {
  final lang = context.locale.languageCode;
  return switch (p.kind) {
    StatsPeriodKind.year => '${p.from.year}',
    StatsPeriodKind.month => DateFormat.yMMMM(lang).format(p.from),
    _ => '${DateFormat.yMMMd(lang).format(p.from)} – ${DateFormat.yMMMd(lang).format(p.to)}',
  };
}

/// Statistics: Summary (dashboard for the period) and Details (income / expenses / car /
/// installments, every entry opens its record for editing). The period is chosen at the bottom.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  Future<void> _pickMonth(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final lang = context.locale.languageCode;
    final m = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('stats.pickMonth'.tr(), style: Theme.of(ctx).textTheme.titleMedium),
              ),
              for (var i = 1; i <= 24; i++)
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text(DateFormat.yMMMM(lang).format(DateTime(now.year, now.month - i))),
                  onTap: () => Navigator.pop(ctx, DateTime(now.year, now.month - i)),
                ),
            ],
          ),
        ),
      ),
    );
    if (m != null) ref.read(statsPeriodProvider.notifier).set(StatsPeriod.month(m));
  }

  Future<void> _pickYear(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final y = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('stats.pickYear'.tr(), style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (var y = now.year; y >= now.year - 5; y--)
              ListTile(leading: const Icon(Icons.event_note_outlined), title: Text('$y'), onTap: () => Navigator.pop(ctx, y)),
          ],
        ),
      ),
    );
    if (y != null) ref.read(statsPeriodProvider.notifier).set(StatsPeriod.year(y));
  }

  Future<void> _custom(BuildContext context, WidgetRef ref) async {
    final current = ref.read(statsPeriodProvider);
    final p = await Navigator.of(
      context,
    ).push<StatsPeriod>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => StatsCustomPeriodScreen(initial: current)));
    if (p != null) ref.read(statsPeriodProvider.notifier).set(p);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statsPeriodProvider);
    final data = ref.watch(statsDataProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('stats.title'.tr()),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(78),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.date_range, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _range(context, period),
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      if (period.categoryId != null) ...[const SizedBox(width: 6), const Icon(Icons.filter_alt, size: 16)],
                    ],
                  ),
                ),
                TabBar(
                  tabs: [
                    Tab(text: 'stats.summary'.tr()),
                    Tab(text: 'stats.details'.tr()),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: data == null ? const Center(child: CircularProgressIndicator()) : TabBarView(children: [_Summary(data), _Details(data)]),
        bottomNavigationBar: NavigationBar(
          height: 64,
          selectedIndex: period.kind.index,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) => switch (i) {
            0 => ref.read(statsPeriodProvider.notifier).current(),
            1 => _pickMonth(context, ref),
            2 => _pickYear(context, ref),
            _ => _custom(context, ref),
          },
          destinations: [
            NavigationDestination(icon: const Icon(Icons.today_outlined), label: 'stats.currentMonth'.tr()),
            NavigationDestination(icon: const Icon(Icons.history), label: 'stats.pastMonths'.tr()),
            NavigationDestination(icon: const Icon(Icons.calendar_view_month_outlined), label: 'stats.years'.tr()),
            NavigationDestination(icon: const Icon(Icons.tune), label: 'stats.custom'.tr()),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Summary

class _Summary extends StatelessWidget {
  const _Summary(this.d);
  final StatsData d;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final egp = 'common.egp'.tr();
    Widget kpi(String label, String value, {Color? color, IconData? icon, VoidCallback? onTap}) => Expanded(
      child: AppCard(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) Icon(icon, size: 16, color: color ?? theme.colorScheme.onSurfaceVariant),
                if (icon != null) const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
    String money(double v) => '${formatAmount(double.parse(v.toStringAsFixed(2)))} $egp';
    void openDetails(int tab) {
      DefaultTabController.of(context).animateTo(1);
      _detailsTab.value = tab;
    }

    final cats = d.byMainCategory;
    final accounts = d.byAccount;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Row(
          children: [
            kpi('dashboard.income'.tr(), money(d.totalIncome), color: DS.success, icon: Icons.south_west, onTap: () => openDetails(0)),
            kpi(
              'dashboard.expenses'.tr(),
              money(d.totalExpense),
              color: theme.colorScheme.error,
              icon: Icons.north_east,
              onTap: () => openDetails(1),
            ),
          ],
        ),
        Row(
          children: [
            kpi(
              'export.net'.tr(),
              money(d.net),
              color: d.net >= 0 ? DS.success : theme.colorScheme.error,
              icon: Icons.account_balance_wallet_outlined,
            ),
            kpi(
              'stats.savingsRate'.tr(),
              d.savingsRate == null ? '—' : '${d.savingsRate!.toStringAsFixed(1)}%',
              icon: Icons.savings_outlined,
            ),
          ],
        ),
        Row(
          children: [
            kpi('stats.dailyAverage'.tr(), money(d.dailyAverage), icon: Icons.calendar_today_outlined),
            kpi('stats.count'.tr(), '${d.income.length + d.expenses.length}', icon: Icons.receipt_long_outlined),
          ],
        ),
        Row(
          children: [
            kpi('cars.title'.tr(), money(d.carTotal), icon: Icons.directions_car_outlined, onTap: () => openDetails(2)),
            kpi('installments.title'.tr(), money(d.installmentsPaid), icon: Icons.event_repeat, onTap: () => openDetails(3)),
          ],
        ),
        if (d.installmentsDue > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AppCard(
              color: DS.warning.withValues(alpha: 0.12),
              padding: const EdgeInsets.all(12),
              onTap: () => openDetails(3),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: DS.warning),
                  const SizedBox(width: 8),
                  Expanded(child: Text('stats.installmentsDue'.tr(namedArgs: {'amount': money(d.installmentsDue)}))),
                ],
              ),
            ),
          ),
        SectionHeader('stats.trend'.tr()),
        AppCard(child: _TrendBars(d)),
        SectionHeader('stats.byCategory'.tr()),
        AppCard(
          child: cats.isEmpty
              ? Text('dashboard.noSpending'.tr(), style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
              : Column(
                  children: [
                    for (final c in cats)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text('${c.$2} ${c.$1}'),
                                const Spacer(),
                                AmountText(c.$4, size: 13),
                                SizedBox(
                                  width: 46,
                                  child: Text(
                                    '${(c.$4 / d.totalExpense * 100).round()}%',
                                    textAlign: TextAlign.end,
                                    style: theme.textTheme.labelMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(value: c.$4 / d.totalExpense, minHeight: 5, color: colorFromHex(c.$3)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        if (accounts.isNotEmpty) ...[
          SectionHeader('stats.byAccount'.tr()),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final a in accounts)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: Text(a.$1),
                    trailing: AmountText(a.$2, size: 13),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Which details tab to open when a summary card is tapped.
final _detailsTab = ValueNotifier<int>(1);

class _TrendBars extends StatelessWidget {
  const _TrendBars(this.d);
  final StatsData d;

  @override
  Widget build(BuildContext context) {
    final data = d.trend;
    final scheme = Theme.of(context).colorScheme;
    final daily = d.period.days <= 62;
    final maxY = data.fold<double>(0, (m, x) => [m, x.$2, x.$3].reduce((a, b) => a > b ? a : b));
    final lang = context.locale.languageCode;
    final step = (data.length / 6).ceil().clamp(1, 1000);
    return Column(
      children: [
        SizedBox(
          height: 170,
          child: BarChart(
            BarChartData(
              maxY: maxY == 0 ? 1 : maxY * 1.15,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= data.length || i % step != 0) return const SizedBox.shrink();
                      final dt = data[i].$1;
                      return Text(daily ? '${dt.day}' : DateFormat.MMM(lang).format(dt), style: const TextStyle(fontSize: 9));
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < data.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 1,
                    barRods: [
                      if (!daily) BarChartRodData(toY: data[i].$2, color: DS.success, width: 6, borderRadius: BorderRadius.circular(2)),
                      BarChartRodData(toY: data[i].$3, color: scheme.error, width: daily ? 5 : 6, borderRadius: BorderRadius.circular(2)),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text((daily ? 'stats.dailyExpenses' : 'stats.monthlyIncomeExpenses').tr(), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Details

class _Details extends StatefulWidget {
  const _Details(this.d);
  final StatsData d;

  @override
  State<_Details> createState() => _DetailsState();
}

class _DetailsState extends State<_Details> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 4, vsync: this, initialIndex: _detailsTab.value);

  void _follow() => _tabs.animateTo(_detailsTab.value);

  @override
  void initState() {
    super.initState();
    _detailsTab.addListener(_follow);
  }

  @override
  void dispose() {
    _detailsTab.removeListener(_follow);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final theme = Theme.of(context);
    Widget header(String label, int count, double total, {Color? color}) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Text('$label · ${'stats.items'.tr(namedArgs: {'n': '$count'})}', style: theme.textTheme.labelLarge),
          const Spacer(),
          AmountText(total, size: 15, color: color),
        ],
      ),
    );
    Widget empty() => Padding(
      padding: const EdgeInsets.all(32),
      child: Center(child: Text('stats.empty'.tr())),
    );
    final lang = context.locale.languageCode;

    return Column(
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          tabs: [
            Tab(text: 'stats.income'.tr()),
            Tab(text: 'stats.expenses'.tr()),
            Tab(text: 'cars.title'.tr()),
            Tab(text: 'installments.title'.tr()),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              // Income
              ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  header('stats.income'.tr(), d.income.length, d.totalIncome, color: DS.success),
                  if (d.income.isEmpty) empty(),
                  for (final t in d.income.reversed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TransactionTile(item: t, showDate: true, onTap: () => context.push('/transactions/${t.transaction.id}/edit')),
                    ),
                ],
              ),
              // Expenses
              ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  header('stats.expenses'.tr(), d.expenses.length, d.totalExpense, color: theme.colorScheme.error),
                  if (d.expenses.isEmpty) empty(),
                  for (final t in d.expenses.reversed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TransactionTile(item: t, showDate: true, onTap: () => context.push('/transactions/${t.transaction.id}/edit')),
                    ),
                ],
              ),
              // Car
              ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  header('cars.title'.tr(), d.carExpenses.length, d.carTotal, color: theme.colorScheme.error),
                  if (d.carExpenses.isEmpty) empty(),
                  for (final (car, e) in d.carExpenses)
                    ListTile(
                      leading: IconBubble(emoji: e.categoryIcon, color: DS.primary, size: 38),
                      title: Text('${car.car.name} · ${e.categoryName}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [
                          DateFormat.MMMd(lang).format(e.transaction.date),
                          if (e.expense.odometer != null)
                            'cars.odometerValue'.tr(namedArgs: {'km': NumberFormat.decimalPattern().format(e.expense.odometer)}),
                          if (e.expense.liters != null)
                            'cars.litersValue'.tr(namedArgs: {'l': NumberFormat('#,##0.##').format(e.expense.liters)}),
                        ].join(' · '),
                      ),
                      trailing: AmountText(-e.transaction.amount, size: 14, signed: true, color: theme.colorScheme.error),
                      onTap: () => context.push('/cars/${car.car.id}/expense?edit=${e.expense.id}'),
                    ),
                ],
              ),
              // Installments
              ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  header('installments.title'.tr(), d.installmentLines.length, d.installmentsPaid + d.installmentsDue),
                  if (d.installmentLines.isEmpty) empty(),
                  for (final l in d.installmentLines)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: l.paid ? DS.success.withValues(alpha: 0.15) : DS.warning.withValues(alpha: 0.15),
                        child: Icon(l.paid ? Icons.check : Icons.schedule, color: l.paid ? DS.success : DS.warning, size: 20),
                      ),
                      title: Text('${l.item.plan.title} · ${l.item.plan.provider}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [
                          '${l.due.number}/${l.item.plan.months}',
                          (l.paid ? 'installments.paidOn' : 'stats.dueOn').tr(namedArgs: {'date': DateFormat.yMMMd(lang).format(l.date)}),
                        ].join(' · '),
                      ),
                      trailing: AmountText(l.amount, size: 14, color: l.paid ? null : DS.warning),
                      onTap: () => context.push('/installments/${l.item.plan.id}'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Custom period

class StatsCustomPeriodScreen extends ConsumerStatefulWidget {
  const StatsCustomPeriodScreen({super.key, required this.initial});
  final StatsPeriod initial;

  @override
  ConsumerState<StatsCustomPeriodScreen> createState() => _StatsCustomPeriodScreenState();
}

class _StatsCustomPeriodScreenState extends ConsumerState<StatsCustomPeriodScreen> {
  late DateTime _from = widget.initial.from;
  late DateTime _to = widget.initial.to;
  late int? _categoryId = widget.initial.categoryId;

  Future<void> _pick(bool from) async {
    final d = await showDatePicker(context: context, initialDate: from ? _from : _to, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d == null) return;
    setState(() {
      if (from) {
        _from = d;
        if (_to.isBefore(d)) _to = d;
      } else {
        _to = d;
        if (_from.isAfter(d)) _from = d;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final tree = ref.watch(categoryTreeProvider(CategoryType.expense)).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text('stats.customTitle'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          FieldRow([
            (
              'stats.from'.tr(),
              PickerField(text: DateFormat.yMMMd(lang).format(_from), trailingIcon: Icons.event_outlined, onTap: () => _pick(true)),
            ),
            (
              'stats.to'.tr(),
              PickerField(text: DateFormat.yMMMd(lang).format(_to), trailingIcon: Icons.event_outlined, onTap: () => _pick(false)),
            ),
          ]),
          FieldLabel('stats.mainCategory'.tr()),
          DropdownButtonFormField<int?>(
            isExpanded: true,
            initialValue: tree.any((n) => n.main.id == _categoryId) ? _categoryId : null,
            items: [
              DropdownMenuItem(value: null, child: Text('stats.allCategories'.tr())),
              for (final n in tree) DropdownMenuItem(value: n.main.id, child: Text('${n.main.icon} ${n.main.name}')),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final (key, days) in [('stats.last7', 7), ('stats.last30', 30), ('stats.last90', 90)])
                ActionChip(
                  label: Text(key.tr()),
                  onPressed: () => setState(() {
                    final now = DateTime.now();
                    _to = DateTime(now.year, now.month, now.day);
                    _from = _to.subtract(Duration(days: days - 1));
                  }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              StatsPeriod(
                kind: StatsPeriodKind.custom,
                from: DateTime(_from.year, _from.month, _from.day),
                to: DateTime(_to.year, _to.month, _to.day),
                categoryId: _categoryId,
              ),
            ),
            child: Text('stats.apply'.tr()),
          ),
        ],
      ),
    );
  }
}
