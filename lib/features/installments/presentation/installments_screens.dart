import 'package:drift/drift.dart' show Value;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../accounts/presentation/account_widgets.dart';
import '../data/installment_reminders.dart';
import '../data/installment_repository.dart';
import '../../../core/utils/currency.dart';

String _date(BuildContext context, DateTime d) => DateFormat.yMMMd(context.locale.languageCode).format(d);

int _daysUntil(DateTime d) {
  final now = DateTime.now();
  return DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
}

/// "باقي ٣ أيام" / "اليوم" / "متأخر ٢ يوم" pill for a due date.
Widget _duePill(BuildContext context, DateTime due) {
  final days = _daysUntil(due);
  if (days < 0) {
    return StatusPill('installments.overdue'.tr(namedArgs: {'days': '${-days}'}), color: Theme.of(context).colorScheme.error);
  }
  if (days == 0) return StatusPill('installments.dueToday'.tr(), color: DS.warning);
  return StatusPill(
    'installments.daysLeft'.tr(namedArgs: {'days': '$days'}),
    color: days <= reminderDaysBefore ? DS.warning : Theme.of(context).colorScheme.primary,
  );
}

/// Installments list (one card per plan).
class InstallmentsScreen extends ConsumerWidget {
  const InstallmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(installmentsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('installments.title'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        shape: const StadiumBorder(),
        onPressed: () => context.push('/installments/new'),
        icon: const Icon(Icons.add),
        label: Text('installments.add'.tr()),
      ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(message: 'common.loadError'.tr(), onRetry: () => ref.invalidate(installmentsProvider)),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.event_repeat,
              title: 'installments.emptyTitle'.tr(),
              message: 'installments.emptyMessage'.tr(),
              actionLabel: 'installments.add'.tr(),
              onAction: () => context.push('/installments/new'),
            );
          }
          final active = items.where((i) => !i.isFinished).toList();
          final monthly = active.fold<double>(0, (s, i) => s + i.plan.installmentAmount);
          final remaining = active.fold<double>(0, (s, i) => s + i.remainingAmount);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            children: [
              AppCard(
                color: theme.colorScheme.primaryContainer,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('installments.monthlyTotal'.tr(), style: theme.textTheme.bodySmall),
                          AmountText(monthly, size: 20, weight: FontWeight.w800),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('installments.remainingTotal'.tr(), style: theme.textTheme.bodySmall),
                          AmountText(remaining, size: 20, weight: FontWeight.w800, color: theme.colorScheme.error),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              for (final item in items) _PlanCard(item),
            ],
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(this.item);
  final InstallmentWithSchedule item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = item.nextDue;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => context.push('/installments/${item.plan.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(icon: Icons.event_repeat, color: item.isFinished ? DS.success : theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.plan.title, style: theme.textTheme.titleSmall),
                    Text(item.plan.provider, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText(item.plan.installmentAmount, size: 15),
                  Text('installments.perMonth'.tr(), style: theme.textTheme.labelSmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: item.plan.months == 0 ? 0 : item.paidCount / item.plan.months, minHeight: 7),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'installments.progress'.tr(namedArgs: {'paid': '${item.paidCount}', 'months': '${item.plan.months}'}),
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              if (next != null) ...[
                Text(_date(context, next.dueDate), style: theme.textTheme.bodySmall),
                const SizedBox(width: 6),
                _duePill(context, next.dueDate),
              ] else
                StatusPill('installments.finished'.tr(), color: DS.success, icon: Icons.check),
            ],
          ),
        ],
      ),
    );
  }
}

/// One plan: summary + full schedule; tap a row to pay / undo.
class InstallmentDetailsScreen extends ConsumerWidget {
  const InstallmentDetailsScreen({super.key, required this.installmentId});
  final int installmentId;

  Future<void> _pay(BuildContext context, WidgetRef ref, Installment plan, InstallmentDue due) async {
    final result = await showModalBottomSheet<_PayResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaySheet(plan: plan, due: due),
    );
    if (result == null) return;
    await ref.read(installmentRepositoryProvider).markPaid(plan, due.number, amount: result.amount, accountId: result.accountId);
  }

  Future<void> _undo(BuildContext context, WidgetRef ref, InstallmentDue due) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('installments.undoTitle'.tr()),
        content: Text('installments.undoMessage'.tr(namedArgs: {'number': '${due.number}'})),
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
    if (ok == true) await ref.read(installmentRepositoryProvider).unmarkPaid(due.payment!);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('installments.deleteTitle'.tr()),
        content: Text('installments.deleteMessage'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error, minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(installmentRepositoryProvider).delete(installmentId);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(installmentProvider(installmentId)).value;
    final theme = Theme.of(context);
    if (item == null) return Scaffold(appBar: AppBar(), body: const SizedBox());
    final plan = item.plan;
    return Scaffold(
      appBar: AppBar(
        title: Text(plan.title),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/installments/${plan.id}/edit')),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, ref)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          AppCard(
            child: Column(
              children: [
                _kv(context, 'installments.provider'.tr(), Text(plan.provider, style: theme.textTheme.titleSmall)),
                _kv(context, 'installments.total'.tr(), AmountText(plan.totalAmount)),
                _kv(context, 'installments.installmentAmount'.tr(), AmountText(plan.installmentAmount)),
                _kv(context, 'installments.paid'.tr(), AmountText(item.paidAmount, color: DS.success)),
                _kv(context, 'installments.remaining'.tr(), AmountText(item.remainingAmount, color: theme.colorScheme.error)),
                _kv(context, 'installments.dueDayLabel'.tr(), Text('installments.dayOfMonth'.tr(namedArgs: {'day': '${plan.dueDay}'}))),
                _kv(
                  context,
                  'installments.reminders'.tr(),
                  Text((plan.remindersEnabled ? 'installments.remindersOn' : 'security.off').tr(), style: theme.textTheme.bodySmall),
                ),
                if (plan.notes != null && plan.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(plan.notes!, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          SectionHeader('installments.schedule'.tr()),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final due in item.schedule)
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: due.isPaid ? DS.success.withValues(alpha: 0.15) : theme.colorScheme.surfaceContainerHighest,
                      child: due.isPaid
                          ? const Icon(Icons.check, size: 18, color: DS.success)
                          : Text('${due.number}', style: theme.textTheme.labelMedium),
                    ),
                    title: Text(_date(context, due.dueDate)),
                    subtitle: due.isPaid ? Text('installments.paidOn'.tr(namedArgs: {'date': _date(context, due.payment!.paidAt)})) : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AmountText(due.payment?.amount ?? plan.installmentAmount, size: 13),
                        if (!due.isPaid) ...[const SizedBox(width: 6), _duePill(context, due.dueDate)],
                      ],
                    ),
                    onTap: () => due.isPaid ? _undo(context, ref, due) : _pay(context, ref, plan, due),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, Widget v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(k, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const Spacer(),
        v,
      ],
    ),
  );
}

class _PayResult {
  const _PayResult(this.amount, this.accountId);
  final double amount;
  final int? accountId;
}

class _PaySheet extends ConsumerStatefulWidget {
  const _PaySheet({required this.plan, required this.due});
  final Installment plan;
  final InstallmentDue due;

  @override
  ConsumerState<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends ConsumerState<_PaySheet> {
  late final _amount = TextEditingController(text: widget.plan.installmentAmount.toStringAsFixed(2));
  bool _asExpense = true;
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
    AccountWithBalance? account;
    for (final a in accounts) {
      if (a.account.id == _accountId) account = a;
    }
    final amount = parseAmount(_amount.text);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'installments.payTitle'.tr(namedArgs: {'number': '${widget.due.number}', 'months': '${widget.plan.months}'}),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            FieldLabel('transactions.amount'.tr()),
            AmountField(controller: _amount, onChanged: (_) => setState(() {})),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _asExpense,
              onChanged: (v) => setState(() => _asExpense = v),
              title: Text('installments.recordExpense'.tr()),
            ),
            if (_asExpense)
              PickerField(
                text: account?.account.name ?? 'accounts.choose'.tr(),
                placeholder: account == null,
                leading: account == null ? null : AccountBubble(account, size: 28),
                onTap: () async {
                  final id = await showAccountPicker(context, selectedId: _accountId);
                  if (id != null) setState(() => _accountId = id);
                },
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: amount <= 0 ? null : () => Navigator.pop(context, _PayResult(amount, _asExpense ? _accountId : null)),
              child: Text('installments.markPaid'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add / edit a plan.
class InstallmentFormScreen extends ConsumerStatefulWidget {
  const InstallmentFormScreen({super.key, this.installmentId});
  final int? installmentId;

  @override
  ConsumerState<InstallmentFormScreen> createState() => _InstallmentFormScreenState();
}

class _InstallmentFormScreenState extends ConsumerState<InstallmentFormScreen> {
  final _title = TextEditingController();
  final _provider = TextEditingController();
  final _total = TextEditingController();
  final _installment = TextEditingController();
  final _months = TextEditingController(text: '12');
  final _notes = TextEditingController();
  int _dueDay = DateTime.now().day.clamp(1, 28);
  DateTime _startMonth = DateTime(DateTime.now().year, DateTime.now().month + 1);
  bool _reminders = true;
  bool _installmentEdited = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.installmentId == null) {
      _loaded = true;
    } else {
      ref.read(installmentRepositoryProvider).loadAll().then((all) {
        final item = all.where((x) => x.plan.id == widget.installmentId).firstOrNull;
        if (item == null || !mounted) return;
        final p = item.plan;
        setState(() {
          _title.text = p.title;
          _provider.text = p.provider;
          _total.text = p.totalAmount.toStringAsFixed(2);
          _installment.text = p.installmentAmount.toStringAsFixed(2);
          _months.text = '${p.months}';
          _notes.text = p.notes ?? '';
          _dueDay = p.dueDay;
          _startMonth = p.startMonth;
          _reminders = p.remindersEnabled;
          _installmentEdited = true;
          _loaded = true;
        });
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _provider, _total, _installment, _months, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => parseAmount(c.text);
  int get _monthsValue => int.tryParse(asciiDigits(_months.text).trim()) ?? 0;

  /// Suggests total / months until the user types their own installment amount.
  void _recalc() {
    if (_installmentEdited) return;
    final total = _num(_total);
    final months = _monthsValue;
    _installment.text = total > 0 && months > 0 ? (total / months).toStringAsFixed(2) : '';
  }

  bool get _valid =>
      _title.text.trim().isNotEmpty &&
      _provider.text.trim().isNotEmpty &&
      _num(_total) > 0 &&
      _num(_installment) > 0 &&
      _monthsValue > 0 &&
      _monthsValue <= 360;

  Future<void> _save() async {
    if (!_valid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('installments.missingFields'.tr())));
      return;
    }
    setState(() => _saving = true);
    final data = InstallmentsCompanion(
      title: Value(_title.text.trim()),
      provider: Value(_provider.text.trim()),
      totalAmount: Value(_num(_total)),
      installmentAmount: Value(_num(_installment)),
      months: Value(_monthsValue),
      dueDay: Value(_dueDay),
      startMonth: Value(DateTime(_startMonth.year, _startMonth.month)),
      notes: Value(_notes.text.trim().isEmpty ? null : _notes.text.trim()),
      remindersEnabled: Value(_reminders),
    );
    final repo = ref.read(installmentRepositoryProvider);
    try {
      if (widget.installmentId == null) {
        await repo.create(data);
      } else {
        await repo.update(widget.installmentId!, data);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${'cars.saveFailed'.tr()}: $e')));
      }
      return;
    }
    if (_reminders) await InstallmentReminders.instance.requestPermission();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = dueDateFor(_startMonth, _dueDay, 1);
    final last = dueDateFor(_startMonth, _dueDay, _monthsValue < 1 ? 1 : _monthsValue);
    return Scaffold(
      appBar: AppBar(title: Text((widget.installmentId == null ? 'installments.add' : 'installments.edit').tr())),
      body: !_loaded
          ? const SizedBox()
          : StickySaveLayout(
              button: FilledButton(onPressed: _saving ? null : _save, child: Text('common.save'.tr())),
              children: [
                FieldLabel('installments.itemTitle'.tr()),
                TextField(
                  controller: _title,
                  decoration: InputDecoration(hintText: 'installments.itemHint'.tr()),
                  onChanged: (_) => setState(() {}),
                ),
                FieldLabel('installments.provider'.tr()),
                TextField(
                  controller: _provider,
                  decoration: InputDecoration(hintText: 'installments.providerHint'.tr()),
                  onChanged: (_) => setState(() {}),
                ),
                FieldRow(
                  flex: const [3, 2],
                  [
                    ('installments.total'.tr(), AmountField(compact: true, controller: _total, onChanged: (_) => setState(_recalc))),
                    (
                      'installments.months'.tr(),
                      TextField(
                        controller: _months,
                        keyboardType: TextInputType.number,
                        inputFormatters: [const AsciiDigitsFormatter(), FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => setState(_recalc),
                      ),
                    ),
                  ],
                ),
                FieldRow(
                  flex: const [3, 2],
                  [
                    (
                      'installments.installmentAmount'.tr(),
                      AmountField(compact: true, controller: _installment, onChanged: (_) => setState(() => _installmentEdited = true)),
                    ),
                    (
                      'installments.dueDayLabel'.tr(),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _dueDay,
                        items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d'))],
                        onChanged: (v) => setState(() => _dueDay = v ?? _dueDay),
                      ),
                    ),
                  ],
                ),
                FieldLabel('installments.startMonth'.tr()),
                PickerField(
                  text: DateFormat.yMMMM(context.locale.languageCode).format(_startMonth),
                  trailingIcon: Icons.calendar_month_outlined,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _startMonth,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDatePickerMode: DatePickerMode.year,
                    );
                    if (d != null) setState(() => _startMonth = DateTime(d.year, d.month));
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'installments.scheduleHint'.tr(namedArgs: {'first': _date(context, first), 'last': _date(context, last)}),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _reminders,
                  onChanged: (v) => setState(() => _reminders = v),
                  title: Text('installments.reminders'.tr()),
                  subtitle: Text('installments.remindersHint'.tr(), style: theme.textTheme.bodySmall),
                ),
                FieldLabel('installments.notes'.tr()),
                TextField(controller: _notes, minLines: 1, maxLines: 3),
              ],
            ),
    );
  }
}
