import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../reports/data/report_export.dart';
import '../domain/finishing_rules.dart';
import 'finishing_repository.dart';

/// Translator handed in by the screen (keeps this file free of BuildContext).
typedef Tr = String Function(String key, {Map<String, String>? args});

final _money = NumberFormat('#,##0.00', 'en');
String _m(int piasters) => _money.format(fromPiasters(piasters));
String _signed(int p) => p == 0 ? '' : '${p > 0 ? '+' : '−'}${_m(p.abs())}';

/// Everything the PDF / Excel show, computed once.
class _Sheet {
  _Sheet(this.d, this.t, this.lang);
  final ProjectDetails d;
  final Tr t;
  final String lang;

  String date(DateTime x) => '${x.year}/${x.month.toString().padLeft(2, '0')}/${x.day.toString().padLeft(2, '0')}';
  String kind(String k) => t('finishing.kind.$k');

  List<FinishingEventView> get costs => [
    for (final e in d.events.reversed)
      if (e.kind == FinishingKind.cost && !e.reversed) e,
  ];

  List<String> get closureLines {
    final s = d.statement;
    int sum(bool Function(StatementLine) f, int Function(StatementLine) v) => s.where(f).fold(0, (a, l) => a + v(l));
    final spent = sum((l) => l.kind == FinishingKind.cost, (l) => l.event.custodyShare);
    final reimb = sum((l) => l.kind == FinishingKind.reimburseFromCustody, (l) => l.event.amount);
    final repaid = sum((l) => l.kind == FinishingKind.clientRepayPersonal, (l) => l.event.amount);
    return [
      '${t('finishing.custodyIn')}: ${_m(d.custodyIn)}',
      '${t('finishing.report.custodySpent')}: ${_m(spent)}',
      '${t('finishing.kind.reimburseFromCustody')}: ${_m(reimb)}',
      '${t('finishing.custodyReturned')}: ${_m(d.custodyOut)}',
      '${t('finishing.report.custodyLeft')}: ${_m(d.balance.custody)}',
      '${t('finishing.report.personalPaid')}: ${_m(d.personalPaid)}',
      '${t('finishing.kind.clientRepayPersonal')}: ${_m(repaid)}',
      '${t('finishing.report.receivableLeft')}: ${_m(d.balance.receivable)}',
    ];
  }
}

Future<Uint8List> buildProjectPdf(ProjectDetails d, Tr t, String lang) async {
  final s = _Sheet(d, t, lang);
  final theme = await loadReportPdfTheme();
  final rtl = lang == 'ar';
  const green = PdfColor.fromInt(0xFF0F5C3E);
  const light = PdfColor.fromInt(0xFFEFF5F1);
  final p = d.project;
  final b = d.balance;

  pw.Widget title(String x) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
    child: pw.Text(
      x,
      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: green),
    ),
  );
  pw.Widget kpi(String label, int v) => pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.symmetric(horizontal: 3),
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(color: light, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pdfCell(_m(v), 11, bold: true),
        ],
      ),
    ),
  );
  pw.Widget table(List<String> head, List<List<String>> rows) => pw.TableHelper.fromTextArray(
    headers: head,
    data: rows,
    headerDecoration: const pw.BoxDecoration(color: green),
    headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
    cellStyle: const pw.TextStyle(fontSize: 8),
    cellAlignment: rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
    oddRowDecoration: const pw.BoxDecoration(color: light),
    cellBuilder: (col, row, v) => pdfCell('$v', 8),
  );

  final doc = pw.Document(theme: theme, title: p.name);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      margin: const pw.EdgeInsets.all(26),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: green, width: 1.2)),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    p.name,
                    style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: green),
                  ),
                  pw.Text('${t('finishing.client')}: ${p.clientName}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(t('finishing.report.title'), style: const pw.TextStyle(fontSize: 9)),
                pdfCell(s.date(DateTime.now()), 8),
                pw.Text(p.closed ? t('finishing.closed') : t('finishing.status.${p.workStatus}'), style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ],
        ),
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ),
      build: (_) => [
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            kpi(t('finishing.cost'), b.cost),
            kpi(t('finishing.custody'), b.custody),
            kpi(t('finishing.receivable'), b.receivable),
            kpi(t('finishing.allocation'), b.allocation),
            if (p.plannedBudget > 0) kpi(t('finishing.plannedBudget'), p.plannedBudget),
          ],
        ),
        title(t('finishing.costByTrade')),
        table(
          [t('finishing.trade'), t('finishing.report.count'), t('finishing.cost')],
          [
            for (final x in d.byTrade.where((x) => x.total > 0)) [x.trade.name, '${x.count}', _m(x.total)],
          ],
        ),
        title(t('finishing.costByType')),
        table(
          [t('finishing.costTypeLabel'), t('finishing.cost')],
          [
            for (final c in CostType.values) [t('finishing.costType.${c.name}'), _m(d.byType[c] ?? 0)],
          ],
        ),
        title(t('finishing.report.costs')),
        table(
          [
            t('transactions.date'),
            t('finishing.trade'),
            t('finishing.costTypeLabel'),
            t('finishing.costDescription'),
            t('finishing.report.fromCustody'),
            t('finishing.report.fromPocket'),
            t('finishing.cost'),
          ],
          [
            for (final e in s.costs)
              [
                s.date(e.event.date),
                e.tradeName ?? '',
                t('finishing.costType.${e.event.costType ?? 'other'}'),
                [e.event.description ?? '', if ((e.event.beneficiary ?? '').isNotEmpty) '(${e.event.beneficiary})'].join(' '),
                _m(e.event.custodyShare),
                _m(e.event.personalShare),
                _m(e.event.amount),
              ],
          ],
        ),
        title(t('finishing.report.statement')),
        table(
          [
            t('transactions.date'),
            t('finishing.report.movement'),
            t('finishing.custody'),
            t('finishing.report.custodyBalance'),
            t('finishing.receivable'),
            t('finishing.report.receivableBalance'),
          ],
          [
            for (final l in d.statement)
              if (l.custodyDelta != 0 || l.receivableDelta != 0)
                [
                  s.date(l.event.date),
                  [s.kind(l.event.kind), if ((l.event.description ?? '').isNotEmpty) l.event.description!].join(' · '),
                  _signed(l.custodyDelta),
                  _m(l.custodyAfter),
                  _signed(l.receivableDelta),
                  _m(l.receivableAfter),
                ],
          ],
        ),
        if (d.accounts.isNotEmpty) ...[
          title(t('finishing.report.accounts')),
          table(
            [t('transactions.account'), t('finishing.report.in'), t('finishing.report.out'), t('finishing.report.net')],
            [
              for (final a in d.accounts) [a.accountName, _m(a.moneyIn), _m(a.moneyOut), _signed(a.net)],
            ],
          ),
        ],
        title(t('finishing.report.closure')),
        for (final line in s.closureLines) pw.Text(line, style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 4),
        pw.Text(
          b.canClose ? t('finishing.report.closureOk') : t('finishing.report.closureOpen'),
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: b.canClose ? green : PdfColors.orange800),
        ),
      ],
    ),
  );
  return doc.save();
}

Uint8List buildProjectXlsx(ProjectDetails d, Tr t, String lang) {
  final s = _Sheet(d, t, lang);
  XCell h(String x) => XCell(x, bold: true);
  double m(int p) => fromPiasters(p);
  final p = d.project;
  final b = d.balance;
  return buildXlsx([
    (
      t('finishing.tabSummary'),
      [
        [h(p.name)],
        ['${t('finishing.client')}: ${p.clientName}'],
        [],
        [h(t('finishing.cost')), m(b.cost)],
        [h(t('finishing.custody')), m(b.custody)],
        [h(t('finishing.receivable')), m(b.receivable)],
        [h(t('finishing.allocation')), m(b.allocation)],
        if (p.plannedBudget > 0) [h(t('finishing.plannedBudget')), m(p.plannedBudget)],
        [],
        [h(t('finishing.costByTrade'))],
        for (final x in d.byTrade.where((x) => x.total > 0)) [x.trade.name, m(x.total)],
        [],
        [h(t('finishing.costByType'))],
        for (final c in CostType.values) [t('finishing.costType.${c.name}'), m(d.byType[c] ?? 0)],
        [],
        [h(t('finishing.report.closure'))],
        for (final l in s.closureLines) [l],
      ],
      [34, 18],
    ),
    (
      t('finishing.report.costs'),
      [
        [
          h(t('transactions.date')),
          h(t('finishing.trade')),
          h(t('finishing.costTypeLabel')),
          h(t('finishing.costDescription')),
          h(t('finishing.beneficiary')),
          h(t('finishing.report.fromCustody')),
          h(t('finishing.report.fromPocket')),
          h(t('finishing.cost')),
        ],
        for (final e in s.costs)
          [
            s.date(e.event.date),
            e.tradeName ?? '',
            t('finishing.costType.${e.event.costType ?? 'other'}'),
            e.event.description ?? '',
            e.event.beneficiary ?? '',
            m(e.event.custodyShare),
            m(e.event.personalShare),
            m(e.event.amount),
          ],
      ],
      [12, 16, 12, 30, 18, 14, 14, 14],
    ),
    (
      t('finishing.report.statement'),
      [
        [
          h(t('transactions.date')),
          h(t('finishing.report.movement')),
          h(t('finishing.custody')),
          h(t('finishing.report.custodyBalance')),
          h(t('finishing.receivable')),
          h(t('finishing.report.receivableBalance')),
        ],
        for (final l in d.statement)
          [
            s.date(l.event.date),
            [s.kind(l.event.kind), if ((l.event.description ?? '').isNotEmpty) l.event.description!].join(' · '),
            m(l.custodyDelta),
            m(l.custodyAfter),
            m(l.receivableDelta),
            m(l.receivableAfter),
          ],
      ],
      [12, 34, 14, 14, 14, 14],
    ),
    (
      t('finishing.report.accounts'),
      [
        [h(t('transactions.account')), h(t('finishing.report.in')), h(t('finishing.report.out')), h(t('finishing.report.net'))],
        for (final a in d.accounts) [a.accountName, m(a.moneyIn), m(a.moneyOut), m(a.net)],
      ],
      [22, 14, 14, 14],
    ),
  ], rtl: lang == 'ar');
}

/// Projects side by side (UI-11 comparison).
Uint8List buildComparisonXlsx(List<ProjectSummary> list, Map<int, ProjectDetails> details, Tr t, String lang) {
  XCell h(String x) => XCell(x, bold: true);
  double m(int p) => fromPiasters(p);
  return buildXlsx([
    (
      t('finishing.compare.title'),
      [
        [
          h(t('finishing.projectName')),
          h(t('finishing.client')),
          h(t('finishing.plannedBudget')),
          h(t('finishing.cost')),
          for (final c in CostType.values) h(t('finishing.costType.${c.name}')),
          h(t('finishing.custody')),
          h(t('finishing.receivable')),
        ],
        for (final s in list)
          [
            s.project.name,
            s.project.clientName,
            m(s.project.plannedBudget),
            m(s.balance.cost),
            for (final c in CostType.values) m(details[s.project.id]?.byType[c] ?? 0),
            m(s.balance.custody),
            m(s.balance.receivable),
          ],
      ],
      [24, 18, 14, 14, 14, 14, 14, 14, 14],
    ),
  ], rtl: lang == 'ar');
}
