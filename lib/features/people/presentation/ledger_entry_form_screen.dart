import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/tables.dart';
import '../../../core/utils/date_utils.dart';
import '../data/ledger_repository.dart';
import 'people_providers.dart';
import 'person_screen.dart';

/// New shared transaction (or settlement) with a person.
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

  double get _amountValue => double.tryParse(_amount.text.trim()) ?? 0;

  /// For a settlement the natural direction is "pay down what is owed".
  LedgerDirection _defaultDirection(PersonWithBalance? p) {
    if (_kind == LedgerKind.settlement && p != null && p.balance.net > 0) return LedgerDirection.received;
    if (_kind == LedgerKind.settlement) return LedgerDirection.gave;
    return LedgerDirection.received;
  }

  Future<void> _save(LedgerDirection direction) async {
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
        );
    if (mounted) context.pop();
  }

  Future<void> _pickPerson(List<PersonWithBalance> people) async {
    final id = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: Text('people.add'.tr(context: ctx)),
                onTap: () => Navigator.pop(ctx, -1),
              ),
              for (final p in people)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(p.person.name),
                  onTap: () => Navigator.pop(ctx, p.person.id),
                ),
            ],
          ),
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
    final theme = Theme.of(context);
    final shared = selected != null && (selected.person.email?.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(title: Text((widget.settlement ? 'ledger.settlementTitle' : 'ledger.newTitle').tr(context: context))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('ledger.person'.tr(context: context), style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _pickPerson(people),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(child: Text(selected?.person.name ?? 'ledger.choosePerson'.tr(context: context))),
                const Icon(Icons.arrow_drop_down),
              ]),
            ),
          ),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                (shared ? 'ledger.sharedHint' : 'ledger.localHint').tr(namedArgs: {'name': selected.person.name}, context: context),
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
          Text('ledger.kindLabel'.tr(context: context), style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final k in LedgerKind.values)
                ChoiceChip(
                  label: Text(kindLabel(context, k)),
                  selected: _kind == k,
                  onSelected: (_) => setState(() {
                    _kind = k;
                    _direction = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('ledger.direction'.tr(context: context), style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<LedgerDirection>(
            segments: [
              ButtonSegment(value: LedgerDirection.received, label: Text('ledger.received'.tr(context: context)), icon: const Icon(Icons.south_west)),
              ButtonSegment(value: LedgerDirection.gave, label: Text('ledger.gave'.tr(context: context)), icon: const Icon(Icons.north_east)),
            ],
            selected: {direction},
            onSelectionChanged: (s) => setState(() => _direction = s.first),
          ),
          const SizedBox(height: 16),
          Text('transactions.amount'.tr(context: context), style: theme.textTheme.labelLarge),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
            decoration: const InputDecoration(hintText: '0.00'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text('transactions.date'.tr(context: context), style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) setState(() => _date = d);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [Expanded(child: Text(DateFormat.yMMMd().format(_date))), const Icon(Icons.calendar_today, size: 18)]),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _description,
            maxLines: 2,
            decoration: InputDecoration(labelText: '${'ledger.description'.tr(context: context)} (${'common.optional'.tr(context: context)})'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving || _personId == null || _amountValue <= 0 ? null : () => _save(direction),
            child: Text('ledger.save'.tr(context: context)),
          ),
        ],
      ),
    );
  }
}
