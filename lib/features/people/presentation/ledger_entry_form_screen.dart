import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/tables.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../data/ledger_repository.dart';
import 'people_providers.dart';
import 'people_screen.dart';
import 'person_screen.dart';

const _paymentMethods = ['cash', 'bank', 'transfer', 'other'];

/// Shared transaction (PPL-03, mockup 12) or settlement (PPL-05, mockup 13) with a person.
class LedgerEntryFormScreen extends ConsumerStatefulWidget {
  const LedgerEntryFormScreen({super.key, this.personId, this.settlement = false});
  final int? personId;
  final bool settlement;

  @override
  ConsumerState<LedgerEntryFormScreen> createState() => _LedgerEntryFormScreenState();
}

class _LedgerEntryFormScreenState extends ConsumerState<LedgerEntryFormScreen> {
  int? _personId;
  late LedgerKind _kind;
  LedgerDirection? _direction;
  final _amount = TextEditingController();
  final _description = TextEditingController();
  DateTime _date = todayDateOnly();
  String _paymentMethod = 'cash';
  bool _notify = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _personId = widget.personId;
    _kind = widget.settlement ? LedgerKind.settlement : LedgerKind.loan;
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  double get _amountValue => double.tryParse(_amount.text.trim().replaceAll(',', '')) ?? 0;

  /// A settlement pays down what is owed: if I owe them I give, if they owe me I receive.
  LedgerDirection _defaultDirection(PersonWithBalance? p) {
    if (_kind == LedgerKind.settlement) {
      return p != null && p.balance.net > 0 ? LedgerDirection.received : LedgerDirection.gave;
    }
    return LedgerDirection.received;
  }

  Future<void> _save(LedgerDirection direction, bool shared) async {
    final personId = _personId;
    if (personId == null || _amountValue <= 0) return;
    setState(() => _saving = true);
    await ref.read(ledgerRepositoryProvider).createEntry(
          personId: personId,
          kind: _kind,
          direction: direction,
          amount: _amountValue,
          date: _date,
          description: _description.text,
          paymentMethod: _paymentMethod,
          notifyOtherParty: !shared || _notify,
        );
    if (mounted) context.pop();
  }

  Future<void> _pickPerson(List<PersonWithBalance> people) async {
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(shrinkWrap: true, children: [
            ListTile(
              leading: const IconBubble(icon: Icons.person_add_alt_1_outlined, color: DS.primary, size: 38),
              title: Text('people.add'.tr(context: ctx)),
              onTap: () => Navigator.pop(ctx, -1),
            ),
            for (final p in people)
              ListTile(
                leading: PersonAvatar(name: p.person.name, color: netColor(ctx, p.balance.net), size: 38),
                title: Text(p.person.name),
                trailing: AmountText(p.balance.net.abs(), size: 13, color: netColor(ctx, p.balance.net)),
                onTap: () => Navigator.pop(ctx, p.person.id),
              ),
          ]),
        ),
      ),
    );
    if (id == null || !mounted) return;
    if (id == -1) {
      await context.push('/people/new');
      return;
    }
    setState(() {
      _personId = id;
      _direction = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(peopleWithBalancesProvider).value ?? const <PersonWithBalance>[];
    PersonWithBalance? selected;
    for (final p in people) {
      if (p.person.id == _personId) selected = p;
    }
    final direction = _direction ?? _defaultDirection(selected);
    final shared = selected != null && (selected.person.email?.isNotEmpty ?? false);
    final isSettlement = _kind == LedgerKind.settlement;
    final theme = Theme.of(context);
    final title = isSettlement && selected != null
        ? 'ledger.settlementWith'.tr(namedArgs: {'name': selected.person.name})
        : (isSettlement ? 'ledger.settlementTitle' : 'ledger.newTitle').tr();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          if (isSettlement && selected != null)
            AppCard(
              color: theme.colorScheme.primaryContainer,
              child: Column(children: [
                Text('people.currentBalance'.tr(), style: theme.textTheme.bodySmall),
                AmountText(selected.balance.net.abs(), size: 26, weight: FontWeight.w800, color: netColor(context, selected.balance.net)),
                Text(netLabel(context, selected.balance.net), style: TextStyle(color: netColor(context, selected.balance.net))),
              ]),
            ),
          FieldLabel('ledger.person'.tr()),
          PickerField(
            text: selected?.person.name ?? 'ledger.choosePerson'.tr(),
            placeholder: selected == null,
            leading: selected == null ? null : PersonAvatar(name: selected.person.name, color: DS.primary, size: 28),
            onTap: () => _pickPerson(people),
          ),
          if (!isSettlement) ...[
            FieldLabel('ledger.kindLabel'.tr()),
            SegmentedButton<LedgerDirection>(
              segments: [
                ButtonSegment(value: LedgerDirection.received, label: Text('ledger.received'.tr()), icon: const Icon(Icons.south_west)),
                ButtonSegment(value: LedgerDirection.gave, label: Text('ledger.gave'.tr()), icon: const Icon(Icons.north_east)),
              ],
              selected: {direction},
              onSelectionChanged: (s) => setState(() => _direction = s.first),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final k in [LedgerKind.loan, LedgerKind.advance, LedgerKind.other])
                ChoiceChip(label: Text(kindLabel(context, k)), selected: _kind == k, onSelected: (_) => setState(() => _kind = k)),
            ]),
          ],
          FieldLabel((isSettlement ? 'ledger.settlementAmount' : 'transactions.amount').tr()),
          AmountField(controller: _amount, onChanged: (_) => setState(() {})),
          if (isSettlement && selected != null && selected.balance.net != 0)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => setState(() => _amount.text = selected!.balance.net.abs().toStringAsFixed(2)),
                child: Text('ledger.payInFull'.tr()),
              ),
            ),
          FieldLabel('transactions.date'.tr()),
          PickerField(
            text: DateFormat.yMMMMd(context.locale.languageCode).format(_date),
            trailingIcon: Icons.calendar_today_outlined,
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) setState(() => _date = d);
            },
          ),
          FieldLabel('ledger.paymentMethod'.tr()),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: RadioGroup<String>(
              groupValue: _paymentMethod,
              onChanged: (v) => setState(() => _paymentMethod = v ?? 'cash'),
              child: Column(children: [
                for (final m in _paymentMethods) RadioListTile<String>(value: m, dense: true, title: Text('ledger.pay.$m'.tr())),
              ]),
            ),
          ),
          FieldLabel('ledger.description'.tr()),
          TextField(controller: _description, maxLines: 2, decoration: InputDecoration(hintText: 'ledger.descriptionHint'.tr())),
          if (shared)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _notify,
              onChanged: (v) => setState(() => _notify = v),
              title: Text('ledger.notifyOther'.tr()),
              subtitle: Text((_notify ? 'ledger.sharedHint' : 'ledger.privateHint').tr(namedArgs: {'name': selected.person.name}),
                  style: theme.textTheme.bodySmall),
            )
          else if (selected != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('ledger.localHint'.tr(namedArgs: {'name': selected.person.name}), style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving || _personId == null || _amountValue <= 0 ? null : () => _save(direction, shared),
            child: Text((isSettlement ? 'ledger.saveSettlement' : 'ledger.save').tr()),
          ),
        ],
      ),
    );
  }
}
