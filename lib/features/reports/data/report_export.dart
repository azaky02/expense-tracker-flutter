import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/db/tables.dart';
import '../../transactions/data/transaction_models.dart';

/// Labels for the exported files, in the app's current language (filled by the caller so this
/// file stays free of Flutter localization and can be unit-tested).
class ReportLabels {
  const ReportLabels({
    required this.isRtl,
    required this.locale,
    required this.title,
    required this.period,
    required this.preparedFor,
    required this.generatedAt,
    required this.summary,
    required this.income,
    required this.expense,
    required this.net,
    required this.byCategory,
    required this.share,
    required this.transactions,
    required this.date,
    required this.type,
    required this.mainCategory,
    required this.subCategory,
    required this.beneficiary,
    required this.account,
    required this.amount,
    required this.note,
    required this.typeNames,
    required this.total,
    required this.currency,
  });
  final bool isRtl;
  final String locale;
  final String title;
  final String period;
  final String preparedFor;
  final String generatedAt;
  final String summary;
  final String income;
  final String expense;
  final String net;
  final String byCategory;
  final String share;
  final String transactions;
  final String date;
  final String type;
  final String mainCategory;
  final String subCategory;
  final String beneficiary;
  final String account;
  final String amount;
  final String note;
  final Map<TransactionType, String> typeNames;
  final String total;
  final String currency;
}

class CategoryTotal {
  const CategoryTotal(this.name, this.total);
  final String name;
  final double total;
}

/// Everything a report file shows, computed once from the period's transactions.
class ReportData {
  ReportData({required this.from, required this.to, required this.userName, required List<TransactionWithDetails> transactions})
      : transactions = [...transactions]..sort((a, b) => a.transaction.date.compareTo(b.transaction.date)) {
    for (final t in this.transactions) {
      final amount = t.transaction.amount;
      switch (t.transaction.type) {
        case TransactionType.income:
          income += amount;
        case TransactionType.expense:
          expense += amount;
          final main = t.parentCategoryName ?? t.categoryName;
          _byCategory[main] = (_byCategory[main] ?? 0) + amount;
        default:
          break;
      }
    }
  }

  final DateTime from;
  final DateTime to;
  final String userName;
  final List<TransactionWithDetails> transactions;
  double income = 0;
  double expense = 0;
  final _byCategory = <String, double>{};

  double get net => income - expense;
  List<CategoryTotal> get byCategory =>
      [for (final e in _byCategory.entries) CategoryTotal(e.key, e.value)]..sort((a, b) => b.total.compareTo(a.total));

  /// Main / sub category columns: a transaction on a main category has no sub-category.
  static (String, String) categoryColumns(TransactionWithDetails t) =>
      t.parentCategoryName == null ? (t.categoryName, '') : (t.parentCategoryName!, t.categoryName);
}

final _money = NumberFormat('#,##0.00', 'en');

String _ymd(DateTime d, String sep) =>
    '${d.year.toString().padLeft(4, '0')}$sep${d.month.toString().padLeft(2, '0')}$sep${d.day.toString().padLeft(2, '0')}';

String _signed(TransactionWithDetails t) {
  final a = _money.format(t.transaction.amount);
  return switch (t.transaction.type) {
    TransactionType.expense || TransactionType.trustOut => '-$a',
    _ => a,
  };
}

// ---------------------------------------------------------------------------------------------
// PDF

final _arabic = RegExp(r'[؀-ۿ]');

/// The pdf package lays out a whole cell in the page direction, which mirrors Latin-only text
/// (names, numbers, dates) inside an RTL table; give such cells their own LTR direction.
pw.Widget _cell(String s, double size, {bool bold = false}) => pw.Text(
      s,
      textDirection: _arabic.hasMatch(s) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : null),
    );

Future<Uint8List> buildReportPdf(ReportData data, ReportLabels l) async {
  Future<pw.Font> font(String file) async => pw.Font.ttf(await rootBundle.load('assets/fonts/$file'));
  final arabic = await font('NotoSansArabic-Regular.ttf');
  final arabicBold = await font('NotoSansArabic-Bold.ttf');
  final latin = await font('NotoSans-Regular.ttf');
  final latinBold = await font('NotoSans-Bold.ttf');
  final theme = pw.ThemeData.withFont(base: arabic, bold: arabicBold, fontFallback: [latin, latinBold]);
  final dir = l.isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  const navy = PdfColor.fromInt(0xFF0A2A66);
  const light = PdfColor.fromInt(0xFFF0F3F8);

  pw.Widget kpi(String label, double value, PdfColor color) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          margin: const pw.EdgeInsets.symmetric(horizontal: 3),
          decoration: pw.BoxDecoration(color: light, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.Text('${_money.format(value)} ${l.currency}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
          ]),
        ),
      );

  final doc = pw.Document(theme: theme, title: l.title, author: data.userName);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    textDirection: dir,
    margin: const pw.EdgeInsets.all(28),
    header: (ctx) => pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: navy, width: 1.2))),
      child: pw.Row(children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(l.title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: navy)),
            pw.Text(l.period, style: const pw.TextStyle(fontSize: 10)),
          ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          if (data.userName.isNotEmpty) pw.Text(l.preparedFor, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(l.generatedAt, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ]),
      ]),
    ),
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.center,
      child: pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', textDirection: pw.TextDirection.ltr, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ),
    build: (ctx) => [
      pw.SizedBox(height: 10),
      pw.Text(l.summary, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Row(children: [
        kpi(l.income, data.income, PdfColors.green700),
        kpi(l.expense, data.expense, PdfColors.red700),
        kpi(l.net, data.net, data.net >= 0 ? PdfColors.green700 : PdfColors.red700),
      ]),
      if (data.byCategory.isNotEmpty) ...[
        pw.SizedBox(height: 14),
        pw.Text(l.byCategory, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: [l.mainCategory, l.amount, l.share],
          data: [
            for (final c in data.byCategory)
              [
                _cell(c.name, 9),
                _cell(_money.format(c.total), 9),
                _cell('${(data.expense == 0 ? 0 : c.total / data.expense * 100).toStringAsFixed(1)}%', 9),
              ],
            [_cell(l.total, 9, bold: true), _cell(_money.format(data.expense), 9, bold: true), _cell('100%', 9, bold: true)],
          ],
          tableDirection: dir,
          headerDirection: dir,
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: navy),
          cellStyle: const pw.TextStyle(fontSize: 9),
          oddRowDecoration: const pw.BoxDecoration(color: light),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          cellAlignment: l.isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        ),
      ],
      pw.SizedBox(height: 14),
      pw.Text(l.transactions, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: [l.date, l.type, l.mainCategory, l.subCategory, l.beneficiary, l.account, l.amount],
        data: [
          for (final t in data.transactions)
            () {
              final (main, sub) = ReportData.categoryColumns(t);
              return [
                for (final v in [
                  _ymd(t.transaction.date, '/'),
                  l.typeNames[t.transaction.type] ?? '',
                  main,
                  sub,
                  t.transaction.beneficiaryName ?? '',
                  t.accountName ?? '',
                  _signed(t),
                ])
                  _cell(v, 8),
              ];
            }(),
        ],
        tableDirection: dir,
        headerDirection: dir,
        headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: navy),
        cellStyle: const pw.TextStyle(fontSize: 8),
        oddRowDecoration: const pw.BoxDecoration(color: light),
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        cellAlignment: l.isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        columnWidths: const {
          0: pw.FixedColumnWidth(56),
          1: pw.FixedColumnWidth(40),
          6: pw.FixedColumnWidth(62),
        },
        defaultColumnWidth: const pw.FlexColumnWidth(),
      ),
    ],
  ));
  return doc.save();
}

// ---------------------------------------------------------------------------------------------
// Excel (.xlsx written directly: a zip of SpreadsheetML parts)

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    // XML 1.0 forbids most control characters.
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

/// A cell: String (text), num (number, 2 decimals), or null (empty). Bold via [XCell].
class XCell {
  const XCell(this.value, {this.bold = false});
  final Object? value;
  final bool bold;
}

String _colName(int i) {
  var n = i + 1;
  var s = '';
  while (n > 0) {
    final r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

String _sheetXml(List<List<Object?>> rows, {required bool rtl, required List<double> widths}) {
  final b = StringBuffer('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetViews><sheetView workbookViewId="0"${rtl ? ' rightToLeft="1"' : ''}/></sheetViews><cols>');
  for (var i = 0; i < widths.length; i++) {
    b.write('<col min="${i + 1}" max="${i + 1}" width="${widths[i]}" customWidth="1"/>');
  }
  b.write('</cols><sheetData>');
  for (var r = 0; r < rows.length; r++) {
    b.write('<row r="${r + 1}">');
    for (var c = 0; c < rows[r].length; c++) {
      var v = rows[r][c];
      var bold = false;
      if (v is XCell) {
        bold = v.bold;
        v = v.value;
      }
      if (v == null) continue;
      final ref = '${_colName(c)}${r + 1}';
      if (v is num) {
        b.write('<c r="$ref" s="${bold ? 3 : 2}"><v>$v</v></c>');
      } else {
        b.write('<c r="$ref" t="inlineStr"${bold ? ' s="1"' : ''}><is><t xml:space="preserve">${_esc('$v')}</t></is></c>');
      }
    }
    b.write('</row>');
  }
  b.write('</sheetData></worksheet>');
  return b.toString();
}

/// Builds an .xlsx workbook with the given sheets (name → rows).
Uint8List buildXlsx(List<(String, List<List<Object?>>, List<double>)> sheets, {bool rtl = false}) {
  final archive = Archive();
  void add(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '${[for (var i = 0; i < sheets.length; i++) '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
      '</Types>');
  add('_rels/.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>');
  add('xl/workbook.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets>${[for (var i = 0; i < sheets.length; i++) '<sheet name="${_esc(sheets[i].$1)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}</sheets>'
      '</workbook>');
  add('xl/_rels/workbook.xml.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '${[for (var i = 0; i < sheets.length; i++) '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>'].join()}'
      '<Relationship Id="rId${sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>');
  // Styles: 0 normal, 1 bold text, 2 number #,##0.00, 3 bold number.
  add('xl/styles.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
      '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="4">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '<xf numFmtId="4" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="4" fontId="1" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/>'
      '</cellXfs></styleSheet>');
  for (var i = 0; i < sheets.length; i++) {
    add('xl/worksheets/sheet${i + 1}.xml', _sheetXml(sheets[i].$2, rtl: rtl, widths: sheets[i].$3));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Uint8List buildReportXlsx(ReportData data, ReportLabels l) {
  XCell h(String s) => XCell(s, bold: true);
  final summary = <List<Object?>>[
    [h(l.title)],
    [l.period],
    if (data.userName.isNotEmpty) [l.preparedFor],
    [],
    [h(l.summary)],
    [l.income, data.income],
    [l.expense, data.expense],
    [h(l.net), XCell(data.net, bold: true)],
    [],
    [h(l.byCategory)],
    [h(l.mainCategory), h(l.amount), h(l.share)],
    for (final c in data.byCategory) [c.name, c.total, data.expense == 0 ? 0 : double.parse((c.total / data.expense * 100).toStringAsFixed(1))],
    [h(l.total), XCell(data.expense, bold: true)],
  ];
  final rows = <List<Object?>>[
    [h(l.date), h(l.type), h(l.mainCategory), h(l.subCategory), h(l.beneficiary), h(l.account), h(l.amount), h(l.note)],
    for (final t in data.transactions)
      () {
        final (main, sub) = ReportData.categoryColumns(t);
        final out = t.transaction.type == TransactionType.expense || t.transaction.type == TransactionType.trustOut;
        return <Object?>[
          _ymd(t.transaction.date, '-'),
          l.typeNames[t.transaction.type] ?? '',
          main,
          sub,
          t.transaction.beneficiaryName ?? '',
          t.accountName ?? '',
          out ? -t.transaction.amount : t.transaction.amount,
          t.transaction.note ?? '',
        ];
      }(),
  ];
  return buildXlsx([
    (l.summary, summary, [28, 16, 12]),
    (l.transactions, rows, [12, 10, 18, 18, 20, 16, 14, 30]),
  ], rtl: l.isRtl);
}
