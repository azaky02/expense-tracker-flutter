import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/tables.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../data/transaction_models.dart';
import '../data/transaction_repository.dart';
import 'quick_note_dialog.dart';
import 'transaction_providers.dart';
import 'widgets/transaction_tile.dart';

/// Filters currently applied to the transactions list (the filters screen edits a copy).
final transactionFiltersProvider = NotifierProvider<TransactionFiltersNotifier, TransactionFilters>(TransactionFiltersNotifier.new);

class TransactionFiltersNotifier extends Notifier<TransactionFilters> {
  @override
  TransactionFilters build() => const TransactionFilters();
  void set(TransactionFilters f) => state = f;
}

enum _Tab { all, income, expense, transfer }

/// Transactions (UI/UX TRX-01, mockup 6): search, type tabs, filters, timeline grouped by day.
class TransactionsListScreen extends ConsumerStatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  ConsumerState<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends ConsumerState<TransactionsListScreen> {
  final _search = TextEditingController();
  _Tab _tab = _Tab.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  TransactionFilters _effective(TransactionFilters base) {
    final types = switch (_tab) {
      _Tab.all => base.types,
      _Tab.income => {TransactionType.income},
      _Tab.expense => {TransactionType.expense},
      _Tab.transfer => {TransactionType.transfer},
    };
    return base.copyWith(search: _search.text.trim(), types: types, clearTypes: types == null);
  }

  String _dayLabel(DateTime d) {
    final today = todayDateOnly();
    if (d == today) return 'common.today'.tr();
    if (d == today.subtract(const Duration(days: 1))) return 'common.yesterday'.tr();
    return DateFormat.yMMMMEEEEd(context.locale.languageCode).format(d);
  }

  @override
  Widget build(BuildContext context) {
    final base = ref.watch(transactionFiltersProvider);
    final async = ref.watch(transactionsListProvider(_effective(base)));
    final theme = Theme.of(context);
    final filtered = !base.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('nav.transactions'.tr()),
        actions: [
          IconButton(
            onPressed: () => context.push('/transactions/filters'),
            icon: Badge(isLabelVisible: filtered, smallSize: 8, child: const Icon(Icons.tune)),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'transactions.searchHint'.tr(),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(_search.clear)),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final t in _Tab.values)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text('transactions.tab.${t.name}'.tr()),
                    selected: _tab == t,
                    onSelected: (_) => setState(() => _tab = t),
                  ),
                ),
              if (filtered)
                ActionChip(
                  avatar: const Icon(Icons.filter_alt_off_outlined, size: 16),
                  label: Text('transactions.clearFilters'.tr()),
                  onPressed: () => ref.read(transactionFiltersProvider.notifier).set(const TransactionFilters()),
                ),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Padding(padding: EdgeInsets.all(16), child: SkeletonList()),
            error: (e, _) => ErrorState(message: 'common.loadError'.tr(), onRetry: () => ref.invalidate(transactionsListProvider)),
            data: (items) {
              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: filtered || _search.text.isNotEmpty ? 'transactions.noResults'.tr() : 'dashboard.noTransactions'.tr(),
                  actionLabel: filtered ? null : 'add.expense'.tr(),
                  onAction: () => context.push('/transactions/add'),
                );
              }
              final groups = <DateTime, List<TransactionWithDetails>>{};
              for (final t in items) {
                (groups[dateOnly(t.transaction.date)] ??= []).add(t);
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                children: [
                  for (final e in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 6),
                      child: Text(_dayLabel(e.key), style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: Column(children: [
                        for (final t in e.value)
                          TransactionTile(
                            item: t,
                            onTap: () => context.push('/transactions/${t.transaction.id}/edit'),
                            onLongPress: () => _quickNote(t),
                            onDoubleTap: () => _monthTotal(t),
                          ),
                      ]),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ]),
    );
  }

  Future<void> _quickNote(TransactionWithDetails item) async {
    final note = await showQuickNoteDialog(context, item.transaction.note ?? '');
    if (note != null) await ref.read(transactionRepositoryProvider).updateNote(item.transaction.id, note);
  }

  Future<void> _monthTotal(TransactionWithDetails item) async {
    final (start, end) = getMonthRange();
    final total = await ref.read(categoryMonthTotalProvider((item.transaction.categoryId, start, end)).future);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('transactions.monthTotalForCategory'.tr(namedArgs: {'category': item.categoryName, 'amount': formatAmount(total)})),
    ));
  }
}
