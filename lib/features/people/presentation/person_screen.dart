import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart' hide Card;
import '../../../core/db/tables.dart';
import '../../../core/utils/currency.dart';
import '../data/ledger_repository.dart';
import 'people_providers.dart';
import 'people_screen.dart';

String kindLabel(BuildContext context, LedgerKind k) => 'ledger.kind.${k.name}'.tr(context: context);
String statusLabel(BuildContext context, LedgerStatus s) => 'ledger.status.${s.name}'.tr(context: context);
String directionLabel(BuildContext context, LedgerDirection d) =>
    (d == LedgerDirection.gave ? 'ledger.gave' : 'ledger.received').tr(context: context);

Color statusColor(BuildContext context, LedgerStatus s) => switch (s) {
      LedgerStatus.confirmed => Colors.green.shade700,
      LedgerStatus.pending => Colors.amber.shade800,
      LedgerStatus.rejected => Theme.of(context).colorScheme.error,
      LedgerStatus.cancelled => Theme.of(context).colorScheme.onSurfaceVariant,
    };

class PersonScreen extends ConsumerWidget {
  const PersonScreen({super.key, required this.personId});
  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(personProvider(personId)).value;
    final entries = ref.watch(personEntriesProvider(personId)).value ?? const <LedgerEntry>[];
    final balance = PersonBalance.of(entries);
    final theme = Theme.of(context);
    if (person == null) return Scaffold(appBar: AppBar());

    return Scaffold(
      appBar: AppBar(
        title: Text(person.name),
        actions: [
          IconButton(
            onPressed: () => context.push('/people/$personId/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _BalanceRow(label: 'people.heOwesMe'.tr(context: context), amount: balance.heOwesMe, color: Colors.green.shade700),
                  _BalanceRow(label: 'people.iOweHim'.tr(context: context), amount: balance.iOweHim, color: theme.colorScheme.error),
                  const Divider(),
                  _BalanceRow(
                    label: 'people.net'.tr(context: context),
                    amount: balance.net,
                    color: netColor(context, balance.net),
                    bold: true,
                    signed: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    person.linkedUserId != null || (person.email?.isNotEmpty ?? false)
                        ? 'people.linked'.tr(context: context)
                        : 'people.notLinked'.tr(context: context),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/people/$personId/statement'),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text('people.statement'.tr(context: context)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => context.push('/ledger/new?personId=$personId'),
                  icon: const Icon(Icons.add),
                  label: Text('people.newEntry'.tr(context: context)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push('/ledger/new?personId=$personId&kind=settlement'),
                  icon: const Icon(Icons.payments_outlined),
                  label: Text('people.settlement'.tr(context: context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final e in entries) _EntryTile(entry: e),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.label, required this.amount, required this.color, this.bold = false, this.signed = false});
  final String label;
  final double amount;
  final Color color;
  final bool bold;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
          Text(
            '${signed && amount < 0 ? '-' : ''}${formatAmount(amount.abs())}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: bold ? 18 : 15),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry});
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final faded = entry.status == LedgerStatus.rejected || entry.status == LedgerStatus.cancelled;
    return Card(
      child: ListTile(
        onTap: () => showEntrySheet(context, ref, entry),
        leading: Icon(
          entry.direction == LedgerDirection.gave ? Icons.north_east : Icons.south_west,
          color: entry.direction == LedgerDirection.gave ? Colors.green.shade700 : theme.colorScheme.error,
        ),
        title: Text('${kindLabel(context, entry.kind)} · ${directionLabel(context, entry.direction)}'),
        subtitle: Text([
          DateFormat.yMd().format(entry.date),
          statusLabel(context, entry.status),
          if (entry.queued) 'ledger.queued'.tr(context: context),
          if (entry.description != null) entry.description!,
        ].join(' · ')),
        trailing: Text(
          formatAmount(entry.amount),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: faded ? TextDecoration.lineThrough : null,
            color: statusColor(context, entry.status),
          ),
        ),
      ),
    );
  }
}

/// Details of one entry plus the actions allowed for this user: the other party confirms/rejects a
/// pending entry; its creator can withdraw it while pending (or void a one-sided record).
Future<void> showEntrySheet(BuildContext context, WidgetRef ref, LedgerEntry e) {
  final repo = ref.read(ledgerRepositoryProvider);
  final canAnswer = !e.createdByMe && e.status == LedgerStatus.pending;
  final canCancel = e.createdByMe &&
      (e.status == LedgerStatus.pending || (e.status == LedgerStatus.confirmed && e.counterpartUserId == null));
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(formatAmount(e.amount), style: Theme.of(ctx).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('${kindLabel(ctx, e.kind)} · ${directionLabel(ctx, e.direction)}', textAlign: TextAlign.center),
            Text(DateFormat.yMMMd().format(e.date), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(statusLabel(ctx, e.status),
                textAlign: TextAlign.center, style: TextStyle(color: statusColor(ctx, e.status), fontWeight: FontWeight.bold)),
            if (!e.createdByMe && e.counterpartName != null)
              Text('ledger.createdByOther'.tr(namedArgs: {'name': e.counterpartName!}, context: ctx), textAlign: TextAlign.center),
            if (e.description != null) ...[const SizedBox(height: 8), Text(e.description!, textAlign: TextAlign.center)],
            if (e.rejectReason != null)
              Text('ledger.rejectedBecause'.tr(namedArgs: {'reason': e.rejectReason!}, context: ctx), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (canAnswer)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final reason = await _askReason(ctx);
                        if (reason == null) return;
                        await repo.reject(e.entryId, reason);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text('ledger.reject'.tr(context: ctx)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        await repo.confirm(e.entryId);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text('ledger.confirm'.tr(context: ctx)),
                    ),
                  ),
                ],
              ),
            if (canCancel)
              TextButton(
                onPressed: () async {
                  await repo.cancel(e.entryId);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text('ledger.cancel'.tr(context: ctx), style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> _askReason(BuildContext context) async {
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('ledger.reject'.tr(context: ctx)),
      content: TextField(controller: c, decoration: InputDecoration(labelText: 'ledger.rejectReason'.tr(context: ctx))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr(context: ctx))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('ledger.reject'.tr(context: ctx))),
      ],
    ),
  );
  final text = c.text;
  c.dispose();
  return ok == true ? text : null;
}
