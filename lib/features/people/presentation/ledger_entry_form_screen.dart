import 'package:url_launcher/url_launcher.dart';
import 'whatsapp_message.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/tables.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../data/ledger_repository.dart';
import 'people_providers.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../accounts/presentation/account_widgets.dart';
import 'people_screen.dart';
import '../../../core/utils/currency.dart';

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
  int? _accountId;
  bool _notify = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _personId = widget.personId;
    // Loans now live under Installments; entries made here are custody (عهدة).
    _kind = widget.settlement ? LedgerKind.settlement : LedgerKind.advance;
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  double get _amountValue => parseAmount(_amount.text);

  /// A settlement pays down what is owed: if I owe them I give, if they owe me I receive.
  LedgerDirection _defaultDirection(PersonWithBalance? p) {
    if (_kind == LedgerKind.settlement) {
      return p != null && p.balance.net > 0 ? LedgerDirection.received : LedgerDirection.gave;
    }
    return LedgerDirection.received;
  }

  Future<void> _save(LedgerDirection direction, bool shared) async {
    final personId = _personId;
    if (personId == null || _amountValue <= 0 || _saving) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(ledgerRepositoryProvider);
      final previousBalance = (await repo.currentConfirmedBalance(personId)).net;
      await repo.createEntry(
        personId: personId,
        kind: _kind,
        direction: direction,
        amount: _amountValue,
        date: _date,
        description: _description.text,
        paymentMethod: _accountName(),
        notifyOtherParty: !shared || _notify,
        signedIn: ref.read(syncControllerProvider).signedIn,
      );
      if (!mounted) return;
      final currentBalance = (await repo.currentConfirmedBalance(personId)).net;
      final number = await repo.whatsAppNumber(personId);
      if (!mounted) return;
      final wantsShare = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تم حفظ المعاملة'),
          content: const Text('هل تريد مشاركة بيانات المعاملة مع الشخص عبر واتساب؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('نعم، واتساب')),
          ],
        ),
      );
      if (!mounted) return;
      if (wantsShare == true) {
        final digits = whatsAppDigits(number);
        if (digits == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('رقم واتساب غير صالح. استخدم رقمًا بكود الدولة. المعاملة محفوظة.')));
        } else {
          final selectedPerson = (ref.read(peopleWithBalancesProvider).value ?? const <PersonWithBalance>[]).where(
            (p) => p.person.id == personId,
          );
          final name = selectedPerson.isEmpty ? 'الطرف الآخر' : selectedPerson.first.person.name;
          final message = buildLedgerWhatsAppMessage(
            personName: name,
            kind: _kind,
            direction: direction,
            amount: _amountValue,
            date: _date,
            previousBalance: previousBalance,
            currentBalance: currentBalance,
            confirmed: (currentBalance - previousBalance).abs() > 0.005,
            description: _description.text,
          );
          final uri = Uri.https('wa.me', '/$digits', {'text': message});
          if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب. المعاملة محفوظة.')));
          }
        }
      }
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ المعاملة. حاول مرة أخرى.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The chosen account (cash, Visa, ...) is kept on the entry by name.
  String? _accountName() {
    final accounts = ref.read(accountsProvider).value ?? const <AccountWithBalance>[];
    for (final a in accounts) {
      if (a.account.id == _accountId) return a.account.name;
    }
    return accounts.isEmpty ? null : accounts.first.account.name;
  }

  Future<void> _pickPerson(List<PersonWithBalance> people) async {
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
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
    final shared = selected != null && ((selected.person.email?.isNotEmpty ?? false) || (selected.person.phone?.isNotEmpty ?? false));
    final isSettlement = _kind == LedgerKind.settlement;
    final theme = Theme.of(context);
    final title = isSettlement && selected != null
        ? 'ledger.settlementWith'.tr(namedArgs: {'name': selected.person.name})
        : (isSettlement ? 'ledger.settlementTitle' : 'ledger.newTitle').tr();

    return Scaffold(
      appBar: BrandFormAppBar(
        title: title,
        onSave: _saving || _personId == null || _amountValue <= 0 ? null : () => _save(direction, shared),
      ),
      body: StickySaveLayout(
        button: BigSaveButton(
          label: (isSettlement ? 'ledger.saveSettlement' : 'ledger.save').tr(),
          busy: _saving,
          onPressed: _personId == null || _amountValue <= 0 ? null : () => _save(direction, shared),
        ),
        children: [
          if (isSettlement && selected != null)
            AppCard(
              color: theme.colorScheme.primaryContainer,
              child: Column(
                children: [
                  Text('people.currentBalance'.tr(), style: theme.textTheme.bodySmall),
                  AmountText(selected.balance.net.abs(), size: 26, weight: FontWeight.w800, color: netColor(context, selected.balance.net)),
                  Text(netLabel(context, selected.balance.net), style: TextStyle(color: netColor(context, selected.balance.net))),
                ],
              ),
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
          FieldLabel('transactions.account'.tr()),
          Builder(
            builder: (context) {
              final accounts = ref.watch(accountsProvider).value ?? const <AccountWithBalance>[];
              AccountWithBalance? acc;
              for (final x in accounts) {
                if (x.account.id == _accountId) acc = x;
              }
              acc ??= accounts.isEmpty ? null : accounts.first;
              return PickerField(
                text: acc?.account.name ?? 'accounts.choose'.tr(),
                placeholder: acc == null,
                trailingIcon: Icons.chevron_left,
                leading: acc == null ? null : AccountBubble(acc, size: 28),
                onTap: () async {
                  final id = await showAccountPicker(context, selectedId: acc?.account.id);
                  if (id != null) setState(() => _accountId = id);
                },
              );
            },
          ),
          FieldLabel('transactions.notes'.tr()),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(hintText: 'ledger.descriptionHint'.tr()),
          ),
          if (shared)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _notify,
              onChanged: (v) => setState(() => _notify = v),
              title: Text('ledger.notifyOther'.tr()),
              subtitle: Text(
                (_notify ? 'ledger.sharedHint' : 'ledger.privateHint').tr(namedArgs: {'name': selected.person.name}),
                style: theme.textTheme.bodySmall,
              ),
            )
          else if (selected != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('ledger.localHint'.tr(namedArgs: {'name': selected.person.name}), style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}
