import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/tables.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/presentation/category_providers.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';
import '../data/budget_repository.dart';
import 'budget_providers.dart';
import '../../../core/utils/currency.dart';

final budgetsMonthProvider = NotifierProvider<MonthNotifier, DateTime>(MonthNotifier.new);

Color budgetColor(BuildContext context, BudgetStatus b) => switch (b.level) {
  BudgetLevel.ok => colorFromHex(b.category.color),
  BudgetLevel.warning => DS.warning,
  BudgetLevel.reached || BudgetLevel.over => Theme.of(context).colorScheme.error,
};

/// Budgets (UI/UX §14, mockup 15): month, each category's spent / limit with a progress bar and
/// 80 % / 100 % / over-budget states.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(budgetsMonthProvider);
    final async = ref.watch(budgetsForMonthProvider(month));
    final previous = ref.watch(budgetsForMonthProvider(DateTime(month.year, month.month - 1))).value ?? const <BudgetStatus>[];
    final lastMonthSpent = {for (final b in previous) b.category.id: b.spent};
    final pace = MonthPace(month);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('budgets.screenTitle'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(
              child: MonthSelector(month: month, onChanged: (m) => ref.read(budgetsMonthProvider.notifier).set(m)),
            ),
          ),
          const SizedBox(height: 12),
          ...async.when(
            loading: () => [const SkeletonList(count: 4)],
            error: (e, _) => [ErrorState(message: 'common.loadError'.tr())],
            data: (list) => list.isEmpty
                ? [
                    AppCard(
                      child: EmptyState(
                        icon: Icons.pie_chart_outline,
                        title: 'budgets.empty'.tr(),
                        message: 'budgets.emptyHint'.tr(),
                        actionLabel: 'budgets.add'.tr(),
                        onAction: () => _editBudget(context, ref),
                      ),
                    ),
                  ]
                : [
                    _BudgetOverview(list: list, pace: pace, lastMonth: previous.fold<double>(0, (s, b) => s + b.spent)),
                    const SizedBox(height: 12),
                    for (final b in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          onTap: () => _editBudget(context, ref, existing: b),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  IconBubble(emoji: b.category.icon, color: colorFromHex(b.category.color), size: 38),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(b.category.name, style: theme.textTheme.titleSmall),
                                        Row(
                                          children: [
                                            AmountText(b.spent, size: 12, color: theme.colorScheme.onSurfaceVariant),
                                            Text(' / ', style: theme.textTheme.bodySmall),
                                            AmountText(b.limit, size: 12, color: theme.colorScheme.onSurfaceVariant),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${(b.ratio * 100).round()}%',
                                    style: theme.textTheme.titleSmall?.copyWith(color: budgetColor(context, b)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(value: b.ratio.clamp(0, 1), minHeight: 8, color: budgetColor(context, b)),
                              ),
                              const SizedBox(height: 8),
                              _BudgetFacts(b: b, pace: pace, lastMonth: lastMonthSpent[b.category.id]),
                              if (b.level != BudgetLevel.ok) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'budgets.status.${b.level.name}'.tr(),
                                  style: theme.textTheme.bodySmall?.copyWith(color: budgetColor(context, b)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _editBudget(context, ref),
                      icon: const Icon(Icons.add),
                      label: Text('budgets.add'.tr()),
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  Future<void> _editBudget(BuildContext context, WidgetRef ref, {BudgetStatus? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BudgetSheet(existing: existing),
    );
  }
}

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({this.existing});
  final BudgetStatus? existing;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  late int? _categoryId = widget.existing?.category.id;
  late final _limit = TextEditingController(text: widget.existing == null ? '' : widget.existing!.limit.toStringAsFixed(0));

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tree = ref.watch(categoryTreeProvider(CategoryType.expense)).value ?? const <CategoryTreeNode>[];
    final limit = parseAmount(_limit.text);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text((widget.existing == null ? 'budgets.add' : 'budgets.edit').tr(), style: Theme.of(context).textTheme.titleMedium),
          FieldLabel('transactions.category'.tr()),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in tree)
                ChoiceChip(
                  avatar: Text(n.main.icon),
                  label: Text(n.main.name),
                  selected: _categoryId == n.main.id,
                  onSelected: widget.existing != null ? null : (_) => setState(() => _categoryId = n.main.id),
                ),
            ],
          ),
          FieldLabel('budgets.monthlyLimit'.tr()),
          AmountField(controller: _limit, onChanged: (_) => setState(() {})),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _categoryId == null || limit <= 0
                ? null
                : () async {
                    await ref.read(budgetRepositoryProvider).setBudget(_categoryId!, limit);
                    if (context.mounted) Navigator.pop(context);
                  },
            child: Text('common.save'.tr()),
          ),
          if (widget.existing != null)
            TextButton(
              onPressed: () async {
                await ref.read(budgetRepositoryProvider).remove(widget.existing!.budget.id);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('common.delete'.tr(), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }
}

/// Whole-month picture: used %, remaining, pace and the end-of-month projection.
class _BudgetOverview extends StatelessWidget {
  const _BudgetOverview({required this.list, required this.pace, required this.lastMonth});
  final List<BudgetStatus> list;
  final MonthPace pace;
  final double lastMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = list.fold<double>(0, (s, b) => s + b.limit);
    final spent = list.fold<double>(0, (s, b) => s + b.spent);
    final ratio = limit == 0 ? 0.0 : spent / limit;
    final projected = pace.projected(spent);
    final overPace = pace.isCurrent && projected > limit;
    final color = ratio > 1 ? theme.colorScheme.error : (ratio >= 0.8 || overPace ? DS.warning : theme.colorScheme.secondary);
    final change = lastMonth == 0 ? null : (spent - lastMonth) / lastMonth * 100;
    Widget fact(String label, Widget value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          value,
        ],
      ),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('budgets.overview'.tr(), style: theme.textTheme.titleSmall)),
              Text(
                '${(ratio * 100).round()}%',
                style: theme.textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Spending bar with a marker for how much of the month has passed.
          LayoutBuilder(
            builder: (context, c) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: ratio.clamp(0, 1).toDouble(), minHeight: 10, color: color),
                  ),
                  if (pace.isCurrent)
                    PositionedDirectional(
                      start: c.maxWidth * pace.timeRatio - 1,
                      top: -3,
                      child: Container(width: 2, height: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                ],
              );
            },
          ),
          if (pace.isCurrent)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'budgets.timeMarker'.tr(namedArgs: {'p': '${(pace.timeRatio * 100).round()}'}),
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              fact('budgets.spent'.tr(), AmountText(spent, size: 15)),
              fact(
                'budgets.remaining'.tr(),
                AmountText(limit - spent, size: 15, color: limit - spent < 0 ? theme.colorScheme.error : theme.colorScheme.secondary),
              ),
              fact('budgets.limit'.tr(), AmountText(limit, size: 15)),
            ],
          ),
          if (pace.isCurrent) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                fact('budgets.dailyRate'.tr(), AmountText(pace.dailyRate(spent), size: 14)),
                fact('budgets.projected'.tr(), AmountText(projected, size: 14, color: overPace ? theme.colorScheme.error : null)),
                fact(
                  'budgets.perDayLeft'.tr(),
                  pace.dailyAllowance(limit - spent) == null ? const Text('—') : AmountText(pace.dailyAllowance(limit - spent)!, size: 14),
                ),
              ],
            ),
          ],
          if (change != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  change > 0 ? Icons.trending_up : Icons.trending_down,
                  size: 18,
                  color: change > 0 ? theme.colorScheme.error : theme.colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    (change > 0 ? 'budgets.vsLastMore' : 'budgets.vsLastLess').tr(namedArgs: {'p': change.abs().toStringAsFixed(0)}),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          if (overPace)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'budgets.paceWarning'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(color: DS.warning, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

/// Remaining, daily allowance, projection and last month for one budget.
class _BudgetFacts extends StatelessWidget {
  const _BudgetFacts({required this.b, required this.pace, this.lastMonth});
  final BudgetStatus b;
  final MonthPace pace;
  final double? lastMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final allowance = pace.dailyAllowance(b.remaining);
    final projected = pace.projected(b.spent);
    final parts = <String>[
      b.remaining >= 0
          ? 'budgets.leftAmount'.tr(namedArgs: {'amount': formatAmount(b.remaining.roundToDouble())})
          : 'budgets.overAmount'.tr(namedArgs: {'amount': formatAmount((-b.remaining).roundToDouble())}),
      if (pace.isCurrent && allowance != null) 'budgets.perDay'.tr(namedArgs: {'amount': formatAmount(allowance.roundToDouble())}),
      if (pace.isCurrent && projected > b.limit) 'budgets.projectedOver'.tr(namedArgs: {'amount': formatAmount(projected.roundToDouble())}),
      if (lastMonth != null && lastMonth! > 0) 'budgets.lastMonth'.tr(namedArgs: {'amount': formatAmount(lastMonth!.roundToDouble())}),
    ];
    return Text(parts.join(' · '), style: style);
  }
}
