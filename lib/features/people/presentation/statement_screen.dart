import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/db/tables.dart';
import '../../../core/utils/currency.dart';
import '../data/ledger_repository.dart';
import 'people_providers.dart';
import 'people_screen.dart';
import 'person_screen.dart';

/// Statement (كشف حساب): confirmed entries only, oldest first, with a running balance.
class StatementScreen extends ConsumerWidget {
  const StatementScreen({super.key, required this.personId});
  final int personId;

  String _balanceText(BuildContext context, double b) =>
      b == 0 ? 'people.settled'.tr(context: context) : '${formatAmount(b.abs())} ${(b < 0 ? 'statement.payable' : 'statement.receivable').tr(context: context)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(personProvider(personId)).value;
    final lines = ref.watch(statementProvider(personId)).value ?? const <StatementLine>[];
    final theme = Theme.of(context);

    var obligations = 0.0, settlements = 0.0;
    for (final l in lines) {
      if (l.entry.kind == LedgerKind.settlement) {
        settlements += l.entry.amount;
      } else {
        obligations += l.entry.amount;
      }
    }
    final remaining = lines.isEmpty ? 0.0 : lines.last.runningBalance;
    final name = person?.name ?? '';

    String asText() {
      final b = StringBuffer('${'statement.title'.tr(namedArgs: {'name': name}, context: context)}\n\n');
      for (final l in lines) {
        final e = l.entry;
        b.writeln('${DateFormat.yMd().format(e.date)} | ${kindLabel(context, e.kind)} · ${directionLabel(context, e.direction)}'
            '${e.description != null ? ' (${e.description})' : ''} | ${formatAmount(e.amount)} | ${_balanceText(context, l.runningBalance)}');
      }
      b
        ..writeln()
        ..writeln('${'statement.totalObligations'.tr(context: context)}: ${formatAmount(obligations)}')
        ..writeln('${'statement.totalSettlements'.tr(context: context)}: ${formatAmount(settlements)}')
        ..writeln('${'statement.remaining'.tr(context: context)}: ${_balanceText(context, remaining)}');
      return b.toString();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('statement.title'.tr(namedArgs: {'name': name}, context: context)),
        actions: [
          if (lines.isNotEmpty)
            IconButton(
              tooltip: 'statement.share'.tr(context: context),
              icon: const Icon(Icons.share_outlined),
              onPressed: () => SharePlus.instance.share(ShareParams(text: asText())),
            ),
        ],
      ),
      body: lines.isEmpty
          ? Center(child: Text('statement.empty'.tr(context: context)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _row(context, 'statement.totalObligations'.tr(context: context), formatAmount(obligations)),
                        _row(context, 'statement.totalSettlements'.tr(context: context), formatAmount(settlements)),
                        _row(context, 'statement.remaining'.tr(context: context), _balanceText(context, remaining),
                            color: netColor(context, remaining), bold: true),
                        _row(context, 'statement.count'.tr(context: context), '${lines.length}'),
                        _row(context, 'statement.last'.tr(context: context), DateFormat.yMd().format(lines.last.entry.date)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Table header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: DefaultTextStyle(
                    style: theme.textTheme.labelMedium!,
                    child: Row(children: [
                      Expanded(flex: 3, child: Text('statement.date'.tr(context: context))),
                      Expanded(flex: 3, child: Text('statement.debit'.tr(context: context), textAlign: TextAlign.end)),
                      Expanded(flex: 3, child: Text('statement.credit'.tr(context: context), textAlign: TextAlign.end)),
                      Expanded(flex: 4, child: Text('statement.balance'.tr(context: context), textAlign: TextAlign.end)),
                    ]),
                  ),
                ),
                for (final l in lines)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(flex: 3, child: Text(DateFormat.yMd().format(l.entry.date))),
                          // Debit = it adds to what I owe (I received); credit = it adds to what they owe (I gave).
                          Expanded(
                            flex: 3,
                            child: Text(l.entry.direction == LedgerDirection.received ? formatAmount(l.entry.amount) : '—',
                                textAlign: TextAlign.end),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(l.entry.direction == LedgerDirection.gave ? formatAmount(l.entry.amount) : '—',
                                textAlign: TextAlign.end),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(_balanceText(context, l.runningBalance),
                                textAlign: TextAlign.end, style: TextStyle(color: netColor(context, l.runningBalance))),
                          ),
                        ]),
                        Text(
                          [kindLabel(context, l.entry.kind), if (l.entry.description != null) l.entry.description!].join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {Color? color, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : null)),
          ],
        ),
      );
}
