import 'package:drift/drift.dart' show Value;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../accounts/presentation/account_widgets.dart';
import '../../installments/data/installment_repository.dart' show dueDateFor;
import '../data/association_repository.dart';

String _d(BuildContext context, DateTime d) => DateFormat.yMMMd(context.locale.languageCode).format(d);

String _title(Association a) => a.name.isEmpty ? a.owner : a.name;

int _daysUntil(DateTime d) {
  final n = DateTime.now();
  return DateTime(d.year, d.month, d.day).difference(DateTime(n.year, n.month, n.day)).inDays;
}

/// الجمعيات.
class AssociationsScreen extends ConsumerWidget {
  const AssociationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(associationsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('associations.title'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        shape: const StadiumBorder(),
        onPressed: () => context.push('/associations/new'),
        icon: const Icon(Icons.add),
        label: Text('associations.add'.tr()),
      ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(message: 'common.loadError'.tr()),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.groups_2_outlined,
                title: 'associations.emptyTitle'.tr(),
                message: 'associations.emptyMessage'.tr(),
                actionLabel: 'associations.add'.tr(),
                onAction: () => context.push('/associations/new'),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                children: [
                  for (final s in list)
                    AppCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      onTap: () => context.push('/associations/${s.a.id}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconBubble(icon: Icons.groups_2_outlined, color: s.finished ? DS.success : DS.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_title(s.a), style: theme.textTheme.titleSmall),
                                    Text(
                                      'associations.ownerLine'.tr(namedArgs: {'owner': s.a.owner}),
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  AmountText(s.a.shareAmount, size: 14),
                                  Text('associations.perMonth'.tr(), style: theme.textTheme.labelSmall),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(value: s.paidCount / s.a.months, minHeight: 7),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'associations.progress'.tr(namedArgs: {'paid': '${s.paidCount}', 'months': '${s.a.months}'}),
                                style: theme.textTheme.bodySmall,
                              ),
                              const Spacer(),
                              if (s.received)
                                StatusPill('associations.receivedDone'.tr(), color: DS.success, icon: Icons.check)
                              else
                                StatusPill(
                                  'associations.receiveOn'.tr(namedArgs: {'date': _d(context, s.receiveDate)}),
                                  color: _daysUntil(s.receiveDate) <= 31 ? DS.gold : theme.colorScheme.primary,
                                  icon: Icons.savings_outlined,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// One association: summary + monthly schedule (pay the share / receive the pot).
class AssociationDetailsScreen extends ConsumerWidget {
  const AssociationDetailsScreen({super.key, required this.id});
  final int id;

  Future<void> _record(BuildContext context, WidgetRef ref, Association a, AssociationMonth m, {required bool receive}) async {
    final result = await showModalBottomSheet<(double, int?)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RecordSheet(
        title: (receive ? 'associations.receiveTitle' : 'associations.payTitle').tr(
          namedArgs: {'n': '${m.number}', 'months': '${a.months}'},
        ),
        amount: receive ? a.totalAmount : a.shareAmount,
        asTransactionLabel: (receive ? 'associations.asIncome' : 'associations.asExpense').tr(),
      ),
    );
    if (result == null) return;
    await ref.read(associationRepositoryProvider).record(a, m.number, receive: receive, amount: result.$1, accountId: result.$2);
  }

  Future<void> _undo(BuildContext context, WidgetRef ref, AssociationPayment p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('associations.undoTitle'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('installments.undo'.tr()),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(associationRepositoryProvider).undo(p);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = (ref.watch(associationsProvider).value ?? const []).where((x) => x.a.id == id).firstOrNull;
    final theme = Theme.of(context);
    if (s == null) return Scaffold(appBar: AppBar(), body: const SizedBox());
    final a = s.a;
    Widget kv(String k, Widget v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(k, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const Spacer(),
          v,
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(_title(a)),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/associations/${a.id}/edit')),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('associations.deleteTitle'.tr()),
                  content: Text('associations.deleteMessage'.tr()),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error, minimumSize: const Size(88, 44)),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('common.delete'.tr()),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              await ref.read(associationRepositoryProvider).delete(a.id);
              if (context.mounted) context.pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          AppCard(
            color: DS.goldSoft,
            child: Row(
              children: [
                const Icon(Icons.savings_outlined, color: DS.gold, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.received ? 'associations.receivedDone'.tr() : 'associations.youReceive'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(color: DS.text),
                      ),
                      AmountText(a.totalAmount, size: 22, weight: FontWeight.w800, color: DS.text),
                      Text(
                        'associations.turnLine'.tr(namedArgs: {'turn': '${a.myTurn}', 'date': _d(context, s.receiveDate)}),
                        style: theme.textTheme.bodySmall?.copyWith(color: DS.text),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                kv('associations.owner'.tr(), Text(a.owner, style: theme.textTheme.titleSmall)),
                kv('associations.share'.tr(), AmountText(a.shareAmount)),
                kv('associations.months'.tr(), Text('${a.months}')),
                kv('associations.payDay'.tr(), Text('installments.dayOfMonth'.tr(namedArgs: {'day': '${a.payDay}'}))),
                kv('associations.paidSoFar'.tr(), AmountText(s.paidTotal, color: DS.success)),
                if (a.notes != null && a.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(a.notes!, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          SectionHeader('associations.schedule'.tr()),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final m in s.months)
                  Material(
                    color: m.number == a.myTurn ? DS.gold.withValues(alpha: 0.10) : Colors.transparent,
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: m.isPaid ? DS.success.withValues(alpha: 0.15) : theme.colorScheme.surfaceContainerHighest,
                        child: m.isPaid
                            ? const Icon(Icons.check, size: 18, color: DS.success)
                            : Text('${m.number}', style: theme.textTheme.labelMedium),
                      ),
                      title: Text(_d(context, m.date)),
                      subtitle: Text(
                        [
                          m.isPaid ? 'associations.sharePaid'.tr() : 'associations.shareDue'.tr(),
                          if (m.number == a.myTurn) (m.received != null ? 'associations.receivedDone' : 'associations.myTurn').tr(),
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (m.number == a.myTurn)
                            IconButton(
                              tooltip: 'associations.receive'.tr(),
                              icon: Icon(m.received != null ? Icons.savings : Icons.savings_outlined, color: DS.gold),
                              onPressed: () =>
                                  m.received != null ? _undo(context, ref, m.received!) : _record(context, ref, a, m, receive: true),
                            ),
                          AmountText(m.paid?.amount ?? a.shareAmount, size: 13),
                        ],
                      ),
                      onTap: () => m.isPaid ? _undo(context, ref, m.paid!) : _record(context, ref, a, m, receive: false),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordSheet extends ConsumerStatefulWidget {
  const _RecordSheet({required this.title, required this.amount, required this.asTransactionLabel});
  final String title;
  final double amount;
  final String asTransactionLabel;

  @override
  ConsumerState<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends ConsumerState<_RecordSheet> {
  late final _amount = TextEditingController(text: widget.amount.toStringAsFixed(2));
  bool _asTx = true;
  int? _accountId;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value ?? const <AccountWithBalance>[];
    _accountId ??= accounts.where((a) => a.account.type == AccountType.cash).firstOrNull?.account.id ?? accounts.firstOrNull?.account.id;
    final account = accounts.where((a) => a.account.id == _accountId).firstOrNull;
    final amount = parseAmount(_amount.text);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            FieldLabel('transactions.amount'.tr()),
            AmountField(controller: _amount, onChanged: (_) => setState(() {})),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _asTx,
              onChanged: (v) => setState(() => _asTx = v),
              title: Text(widget.asTransactionLabel),
            ),
            if (_asTx)
              PickerField(
                text: account?.account.name ?? 'accounts.choose'.tr(),
                placeholder: account == null,
                leading: account == null ? null : AccountBubble(account, size: 24),
                onTap: () async {
                  final id = await showAccountPicker(context, selectedId: _accountId);
                  if (id != null) setState(() => _accountId = id);
                },
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: amount <= 0 ? null : () => Navigator.pop(context, (amount, _asTx ? _accountId : null)),
              child: Text('common.save'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add / edit an association.
class AssociationFormScreen extends ConsumerStatefulWidget {
  const AssociationFormScreen({super.key, this.id});
  final int? id;

  @override
  ConsumerState<AssociationFormScreen> createState() => _AssociationFormScreenState();
}

class _AssociationFormScreenState extends ConsumerState<AssociationFormScreen> {
  final _name = TextEditingController();
  final _owner = TextEditingController();
  final _share = TextEditingController();
  final _total = TextEditingController();
  final _months = TextEditingController(text: '10');
  final _turn = TextEditingController(text: '1');
  final _notes = TextEditingController();
  DateTime _start = DateTime(DateTime.now().year, DateTime.now().month);
  int _payDay = 1;
  bool _totalEdited = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      ref.read(associationRepositoryProvider).loadAll().then((all) {
        final a = all.where((x) => x.a.id == widget.id).firstOrNull?.a;
        if (a == null || !mounted) return;
        setState(() {
          _name.text = a.name;
          _owner.text = a.owner;
          _share.text = a.shareAmount.toStringAsFixed(2);
          _total.text = a.totalAmount.toStringAsFixed(2);
          _months.text = '${a.months}';
          _turn.text = '${a.myTurn}';
          _notes.text = a.notes ?? '';
          _start = a.startMonth;
          _payDay = a.payDay;
          _totalEdited = true;
        });
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _owner, _share, _total, _months, _turn, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _monthsValue => int.tryParse(asciiDigits(_months.text)) ?? 0;
  int get _turnValue => int.tryParse(asciiDigits(_turn.text)) ?? 0;

  /// The pot defaults to share × number of months.
  void _recalc() {
    if (_totalEdited) return;
    final share = parseAmount(_share.text);
    _total.text = share > 0 && _monthsValue > 0 ? (share * _monthsValue).toStringAsFixed(2) : '';
  }

  String? get _problem {
    if (_owner.text.trim().isEmpty) return 'associations.missingOwner';
    if (parseAmount(_share.text) <= 0) return 'associations.missingShare';
    if (_monthsValue < 2 || _monthsValue > 60) return 'associations.missingMonths';
    if (_turnValue < 1 || _turnValue > _monthsValue) return 'associations.badTurn';
    if (parseAmount(_total.text) <= 0) return 'associations.missingTotal';
    return null;
  }

  Future<void> _save() async {
    final p = _problem;
    if (p != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.tr())));
      return;
    }
    setState(() => _saving = true);
    final data = AssociationsCompanion(
      name: Value(_name.text.trim()),
      owner: Value(_owner.text.trim()),
      shareAmount: Value(parseAmount(_share.text)),
      totalAmount: Value(parseAmount(_total.text)),
      months: Value(_monthsValue),
      myTurn: Value(_turnValue),
      startMonth: Value(DateTime(_start.year, _start.month)),
      payDay: Value(_payDay),
      notes: Value(_notes.text.trim().isEmpty ? null : _notes.text.trim()),
    );
    final repo = ref.read(associationRepositoryProvider);
    if (widget.id == null) {
      await repo.create(data);
    } else {
      await repo.update(widget.id!, data);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = context.locale.languageCode;
    final receive = _turnValue >= 1 && _turnValue <= _monthsValue ? dueDateFor(_start, _payDay, _turnValue) : null;
    final digits = [const AsciiDigitsFormatter(), FilteringTextInputFormatter.digitsOnly];
    return Scaffold(
      appBar: BrandFormAppBar(title: (widget.id == null ? 'associations.add' : 'associations.edit').tr(), onSave: _saving ? null : _save),
      body: StickySaveLayout(
        button: BigSaveButton(label: 'common.save'.tr(), busy: _saving, onPressed: _save),
        children: [
          FieldLabel('associations.owner'.tr()),
          TextField(
            controller: _owner,
            decoration: InputDecoration(hintText: 'associations.ownerHint'.tr()),
            onChanged: (_) => setState(() {}),
          ),
          FieldRow(
            flex: const [3, 2],
            [
              ('associations.share'.tr(), AmountField(compact: true, controller: _share, onChanged: (_) => setState(_recalc))),
              (
                'associations.months'.tr(),
                TextField(
                  controller: _months,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  onChanged: (_) => setState(_recalc),
                ),
              ),
            ],
          ),
          FieldRow(
            flex: const [3, 2],
            [
              (
                'associations.total'.tr(),
                AmountField(compact: true, controller: _total, onChanged: (_) => setState(() => _totalEdited = true)),
              ),
              (
                'associations.myTurnLabel'.tr(),
                TextField(
                  controller: _turn,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          FieldRow([
            (
              'associations.startDate'.tr(),
              PickerField(
                text: DateFormat.yMMMM(lang).format(_start),
                trailingIcon: Icons.calendar_month_outlined,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _start,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDatePickerMode: DatePickerMode.year,
                  );
                  if (d != null) setState(() => _start = DateTime(d.year, d.month));
                },
              ),
            ),
            (
              'associations.payDay'.tr(),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _payDay,
                items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d'))],
                onChanged: (v) => setState(() => _payDay = v ?? _payDay),
              ),
            ),
          ]),
          if (receive != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: AppCard(
                color: DS.goldSoft,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.savings_outlined, color: DS.gold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'associations.receivePreview'.tr(
                          namedArgs: {'date': DateFormat.yMMMd(lang).format(receive), 'amount': formatAmount(parseAmount(_total.text))},
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(color: DS.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'associations.reminderHint'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          OptionalSection(
            initiallyExpanded: _name.text.isNotEmpty || _notes.text.isNotEmpty,
            children: [
              FieldLabel('associations.name'.tr()),
              TextField(
                controller: _name,
                decoration: InputDecoration(hintText: 'associations.nameHint'.tr()),
              ),
              FieldLabel('installments.notes'.tr()),
              TextField(controller: _notes, minLines: 1, maxLines: 3),
            ],
          ),
        ],
      ),
    );
  }
}
