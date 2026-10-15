import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../reports/data/report_export.dart';
import '../data/car_analytics.dart';
import 'car_report_screen.dart';

final _money = NumberFormat('#,##0.00', 'en');
final _n1 = NumberFormat('#,##0.0', 'en');
final _int = NumberFormat('#,##0', 'en');

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _ym(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// The report's key figures as (label, value) rows, shared by the PDF and the workbook.
List<(String, String)> carKpis(CarAnalytics a, Tr t) {
  final egp = t('common.egp');
  String money(double? v) => v == null ? '—' : '${_money.format(v)} $egp';
  return [
    (t('cars.totalSpent'), money(a.totalSpent)),
    (t('carReport.fuel'), money(a.fuelSpent)),
    (t('carReport.otherCosts'), money(a.otherSpent)),
    (t('carReport.kmDriven'), a.kmDriven == null ? '—' : '${_int.format(a.kmDriven)} ${t('cars.km')}'),
    (t('carReport.avgConsumption'), a.avgLitersPer100Km == null ? '—' : t('cars.per100', {'l': _n1.format(a.avgLitersPer100Km)})),
    (t('carReport.kmPerLiter'), a.kmPerLiter == null ? '—' : t('carReport.kmPerLiterValue', {'v': _n1.format(a.kmPerLiter)})),
    (t('carReport.costPerKm'), money(a.costPerKm)),
    (t('carReport.fuelCostPerKm'), money(a.fuelCostPerKm)),
    (t('carReport.avgPrice'), money(a.avgPricePerLiter)),
    (t('cars.totalLiters'), '${_n1.format(a.totalLiters)} ${t('cars.litersUnit')}'),
    (t('carReport.monthlyAvg'), money(a.avgMonthlySpend)),
    (t('carReport.kmPerMonth'), a.avgKmPerMonth == null ? '—' : '${_int.format(a.avgKmPerMonth!.round())} ${t('cars.km')}'),
    (t('cars.tipsTotal'), money(a.totalTips)),
    (t('cars.odometer'), a.lastOdometer == null ? '—' : '${_int.format(a.lastOdometer)} ${t('cars.km')}'),
  ];
}

String _carLine(CarAnalytics a) {
  final c = a.car.car;
  return '${c.brand} · ${c.modelYear}${c.plate == null ? '' : ' · ${c.plate}'}';
}

Future<Uint8List> buildCarReportPdf(CarAnalytics a, Tr t, {required bool rtl, required String generatedAt}) async {
  final theme = await loadReportPdfTheme();
  final dir = rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  const navy = PdfColor.fromInt(0xFF0A2A66);
  const light = PdfColor.fromInt(0xFFF0F3F8);
  final align = rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft;

  pw.Widget title(String s) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
    child: pw.Text(
      s,
      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: navy),
    ),
  );

  pw.Widget table(List<String> headers, List<List<String>> rows, {Map<int, pw.TableColumnWidth>? widths, double size = 8.5}) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: [
          for (final r in rows) [for (final v in r) pdfCell(v, size)],
        ],
        tableDirection: dir,
        headerDirection: dir,
        headerStyle: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: navy),
        oddRowDecoration: const pw.BoxDecoration(color: light),
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        cellAlignment: align,
        columnWidths: widths,
        defaultColumnWidth: const pw.FlexColumnWidth(),
      );

  final kpis = carKpis(a, t);
  final segByEnd = {for (final s in a.segments) s.to.expense.id: s};
  final months = a.monthly().where((m) => m.$2 + m.$3 > 0).toList();
  final insights = carInsights(a, t);

  final doc = pw.Document(theme: theme, title: t('carReport.titleFor', {'car': a.car.car.name}));
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: dir,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: navy, width: 1.2)),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    t('carReport.titleFor', {'car': a.car.car.name}),
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: navy),
                  ),
                  pdfCell(_carLine(a), 10),
                ],
              ),
            ),
            pw.Text(generatedAt, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text(
          '${ctx.pageNumber} / ${ctx.pagesCount}',
          textDirection: pw.TextDirection.ltr,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (ctx) => [
        title(t('export.summary')),
        // Key figures, three per row.
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            for (var i = 0; i < kpis.length; i += 3)
              pw.TableRow(
                children: [
                  for (var j = i; j < i + 3; j++)
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      color: light,
                      child: j >= kpis.length
                          ? pw.SizedBox()
                          : pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(kpis[j].$1, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                                pdfCell(kpis[j].$2, 10.5, bold: true),
                              ],
                            ),
                    ),
                ],
              ),
          ],
        ),
        if (insights.isNotEmpty) ...[
          title(t('carReport.insights')),
          for (final i in insights) pw.Bullet(text: i, style: const pw.TextStyle(fontSize: 9)),
        ],
        title(t('carReport.maintenance')),
        table(
          [t('carReport.status'), t('carReport.due')],
          [
            for (final m in a.maintenance)
              [
                maintenanceText(m, t),
                [
                  if (m.dueKm != null) t('carMaint.atKm', {'km': _int.format(m.dueKm)}),
                  if (m.dueDate != null) _ymd(m.dueDate!),
                ].join(' · '),
              ],
          ],
          widths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1.4)},
        ),
        if (a.stations.isNotEmpty) ...[
          title(t('carReport.bestStations')),
          table(
            [t('cars.station'), t('carReport.avgConsumption'), t('fuel.pricePerLiter'), '#'],
            [
              for (final s in a.stations)
                [
                  s.name,
                  _n1.format(s.litersPer100Km),
                  s.avgPricePerLiter == null ? '—' : _money.format(s.avgPricePerLiter),
                  '${s.segments}',
                ],
            ],
          ),
        ],
        if (a.fuelTypes.length > 1) ...[
          title(t('carReport.byFuelType')),
          table(
            [t('fuel.type'), t('carReport.avgConsumption'), '#'],
            [
              for (final s in a.fuelTypes) [s.name, _n1.format(s.litersPer100Km), '${s.segments}'],
            ],
          ),
        ],
        title(t('carReport.byItem')),
        table(
          [t('transactions.category'), t('transactions.amount'), t('export.share')],
          [
            for (final c in a.byCategory) [c.name, _money.format(c.total), '${(c.total / a.totalSpent * 100).toStringAsFixed(1)}%'],
            [t('export.total'), _money.format(a.totalSpent), '100%'],
          ],
        ),
        if (months.isNotEmpty) ...[
          title(t('carReport.monthly')),
          table(
            [t('carReport.month'), t('carReport.fuel'), t('carReport.otherCosts'), t('export.total')],
            [
              for (final m in months) [_ym(m.$1), _money.format(m.$2), _money.format(m.$3), _money.format(m.$2 + m.$3)],
            ],
          ),
        ],
        if (a.fills.isNotEmpty) ...[
          title(t('carReport.fillLog')),
          table(
            [
              t('transactions.date'),
              t('cars.odometer'),
              t('carReport.distance'),
              t('cars.liters'),
              t('carReport.l100'),
              t('transactions.amount'),
              t('cars.station'),
            ],
            [
              for (final f in a.fills.reversed)
                () {
                  final s = segByEnd[f.expense.id];
                  return [
                    _ymd(f.transaction.date),
                    _int.format(f.expense.odometer),
                    s == null ? '—' : _int.format(s.km),
                    _n1.format(f.expense.liters),
                    s == null ? '—' : _n1.format(s.litersPer100Km),
                    _money.format(f.transaction.amount),
                    stationName(f),
                  ];
                }(),
            ],
            size: 8,
          ),
        ],
        title(t('cars.expenses')),
        table(
          [
            t('transactions.date'),
            t('transactions.category'),
            t('cars.odometer'),
            t('cars.liters'),
            t('transactions.amount'),
            t('cars.paymentMethod'),
          ],
          [
            for (final e in a.car.expenses)
              [
                _ymd(e.transaction.date),
                e.categoryName,
                e.expense.odometer == null ? '' : _int.format(e.expense.odometer),
                e.expense.liters == null ? '' : _n1.format(e.expense.liters),
                _money.format(e.transaction.amount),
                e.accountName ?? '',
              ],
          ],
          size: 8,
        ),
      ],
    ),
  );
  return doc.save();
}

Uint8List buildCarReportXlsx(CarAnalytics a, Tr t, {required bool rtl}) {
  XCell h(String s) => XCell(s, bold: true);
  final segByEnd = {for (final s in a.segments) s.to.expense.id: s};
  double r2(double v) => double.parse(v.toStringAsFixed(2));

  final summary = <List<Object?>>[
    [
      h(t('carReport.titleFor', {'car': a.car.car.name})),
    ],
    [_carLine(a)],
    [],
    [h(t('export.summary'))],
    for (final k in carKpis(a, t)) [k.$1, k.$2],
    [],
    [h(t('carReport.insights'))],
    for (final i in carInsights(a, t)) [i],
    [],
    [h(t('carReport.maintenance'))],
    for (final m in a.maintenance) [maintenanceText(m, t), m.dueDate == null ? '' : _ymd(m.dueDate!), m.dueKm],
  ];
  final fills = <List<Object?>>[
    [
      h(t('transactions.date')),
      h(t('cars.odometer')),
      h(t('carReport.distance')),
      h(t('cars.liters')),
      h(t('carReport.l100')),
      h(t('carReport.kmPerLiter')),
      h(t('transactions.amount')),
      h(t('fuel.pricePerLiter')),
      h(t('fuel.type')),
      h(t('cars.station')),
    ],
    for (final f in a.fills)
      () {
        final s = segByEnd[f.expense.id];
        return <Object?>[
          _ymd(f.transaction.date),
          f.expense.odometer,
          s?.km,
          f.expense.liters,
          s == null ? null : r2(s.litersPer100Km),
          s == null ? null : r2(s.kmPerLiter),
          f.transaction.amount,
          f.expense.pricePerLiter,
          f.fuelTypeName ?? '',
          stationName(f),
        ];
      }(),
  ];
  final expenses = <List<Object?>>[
    [
      h(t('transactions.date')),
      h(t('export.mainCategory')),
      h(t('export.subCategory')),
      h(t('transactions.amount')),
      h(t('cars.odometer')),
      h(t('cars.liters')),
      h(t('cars.station')),
      h(t('cars.paymentMethod')),
      h(t('transactions.notes')),
      h('Lat'),
      h('Lng'),
    ],
    for (final e in a.car.expenses)
      [
        _ymd(e.transaction.date),
        e.parentCategoryName ?? e.categoryName,
        e.parentCategoryName == null ? '' : e.categoryName,
        e.transaction.amount,
        e.expense.odometer,
        e.expense.liters,
        e.transaction.beneficiaryName ?? '',
        e.accountName ?? '',
        e.transaction.note ?? '',
        e.expense.latitude,
        e.expense.longitude,
      ],
  ];
  final stations = <List<Object?>>[
    [h(t('cars.station')), h(t('carReport.avgConsumption')), h(t('fuel.pricePerLiter')), h('#')],
    for (final s in a.stations) [s.name, r2(s.litersPer100Km), s.avgPricePerLiter == null ? null : r2(s.avgPricePerLiter!), s.segments],
    [],
    [h(t('fuel.type')), h(t('carReport.avgConsumption')), h('#')],
    for (final s in a.fuelTypes) [s.name, r2(s.litersPer100Km), s.segments],
  ];
  final monthly = <List<Object?>>[
    [h(t('carReport.month')), h(t('carReport.fuel')), h(t('carReport.otherCosts')), h(t('export.total'))],
    for (final m in a.monthly()) [_ym(m.$1), m.$2, m.$3, m.$2 + m.$3],
    [],
    [h(t('transactions.category')), h(t('transactions.amount'))],
    for (final c in a.byCategory) [c.name, c.total],
  ];
  // Sheet names: Excel allows 31 characters and no []:*?/\ .
  String name(String s) => s.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim().characters31();
  return buildXlsx([
    (name(t('export.summary')), summary, [42, 22, 14]),
    (name(t('carReport.fillLog')), fills, [12, 11, 11, 9, 10, 10, 12, 10, 12, 18]),
    (name(t('cars.expenses')), expenses, [12, 16, 16, 12, 11, 9, 18, 14, 24, 10, 10]),
    (name(t('carReport.stationsSheet')), stations, [24, 16, 14, 6]),
    (name(t('carReport.monthlySheet')), monthly, [16, 14, 16, 14]),
  ], rtl: rtl);
}

extension on String {
  String characters31() => length <= 31 ? this : substring(0, 31);
}
