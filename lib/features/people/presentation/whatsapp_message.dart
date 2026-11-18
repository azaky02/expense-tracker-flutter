import '../../../core/db/tables.dart';

/// Returns digits suitable for wa.me. Egyptian local mobiles are converted to +20.
String? whatsAppDigits(String? raw) {
  if (raw == null) return null;
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (RegExp(r'^01[0125][0-9]{8}$').hasMatch(digits)) {
    digits = '20${digits.substring(1)}';
  }
  if (!RegExp(r'^[1-9][0-9]{7,14}$').hasMatch(digits)) return null;
  return digits;
}

String _money(double value) => value.toStringAsFixed(2);
String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String balanceDescription(double net) {
  if (net > 0.005) return 'مستحق لي عندك';
  if (net < -0.005) return 'مستحق لك عندي';
  return 'الحساب متسوي';
}

/// The shared layout of every WhatsApp notice (people and projects).
String buildWhatsAppNotice({
  required String personName,
  required String typeLabel,
  required double amount,
  required DateTime date,
  required String details,
  required double previousBalance,
  required double currentBalance,
  String Function(double)? describe,
  List<String> extraHeader = const [],
  String? notes,
  String? footerNote,
}) {
  final d = describe ?? balanceDescription;
  return [
    '📱 إشعار من تطبيق مصروفي',
    '',
    'أهلاً أستاذ $personName 👋',
    '',
    'تم تسجيل معاملة مالية بيننا:',
    '',
    ...extraHeader,
    '📌 نوع المعاملة: $typeLabel',
    '💵 مبلغ المعاملة: ${_money(amount)} جنيه',
    '📅 التاريخ: ${_date(date)}',
    '',
    '📝 تفاصيل المعاملة:',
    details,
    if (notes != null && notes.trim().isNotEmpty) 'ملاحظات: ${notes.trim()}',
    '',
    '────────────',
    '💰 ملخص الحساب',
    '',
    'الرصيد السابق: ${_money(previousBalance.abs())} جنيه (${d(previousBalance)})',
    'قيمة المعاملة: ${_money(amount)} جنيه',
    '',
    '💵 الرصيد الحالي: ${_money(currentBalance.abs())} جنيه (${d(currentBalance)})',
    if (footerNote != null) ...['', footerNote],
  ].join('\n');
}

String buildLedgerWhatsAppMessage({
  required String personName,
  required LedgerKind kind,
  required LedgerDirection direction,
  required double amount,
  required DateTime date,
  required double previousBalance,
  required double currentBalance,
  required bool confirmed,
  String? description,
}) {
  final action = direction == LedgerDirection.received ? 'استلمت منك' : 'سلمتك';
  final settlement = kind == LedgerKind.settlement;
  return buildWhatsAppNotice(
    personName: personName,
    typeLabel: settlement ? 'تسوية' : 'عهدة',
    amount: amount,
    date: date,
    details: '$action مبلغ ${_money(amount)} جنيه ${settlement ? 'كتسوية' : 'كعهدة'}.',
    notes: description,
    previousBalance: previousBalance,
    currentBalance: currentBalance,
    footerNote: confirmed ? null : '⏳ المعاملة قيد التأكيد؛ الرصيد المعروض للمعاملات المؤكدة فقط.',
  );
}

/// One movement of a statement, for [buildStatementWhatsAppMessage].
class StatementNoticeLine {
  const StatementNoticeLine({
    required this.date,
    required this.kind,
    required this.direction,
    required this.amount,
    required this.balanceAfter,
    this.description,
  });
  final DateTime date;
  final LedgerKind kind;
  final LedgerDirection direction;
  final double amount;
  final double balanceAfter;
  final String? description;
}

/// The whole statement, in the same layout as the movement notice.
String buildStatementWhatsAppMessage({required String personName, required List<StatementNoticeLine> lines}) {
  var gave = 0.0, received = 0.0;
  for (final l in lines) {
    if (l.direction == LedgerDirection.gave) {
      gave += l.amount;
    } else {
      received += l.amount;
    }
  }
  final current = lines.isEmpty ? 0.0 : lines.last.balanceAfter;
  return [
    '📱 إشعار من تطبيق مصروفي',
    '',
    'أهلاً أستاذ $personName 👋',
    '',
    'ده كشف حساب المعاملات المالية بيننا:',
    '',
    '📋 عدد المعاملات: ${lines.length}',
    if (lines.isNotEmpty) '📅 من ${_date(lines.first.date)} إلى ${_date(lines.last.date)}',
    '',
    '📝 تفاصيل المعاملات:',
    for (final (i, l) in lines.indexed) ...[
      '',
      '${i + 1}) ${_date(l.date)} — ${l.kind == LedgerKind.settlement ? 'تسوية' : 'عهدة'}',
      '${l.direction == LedgerDirection.received ? 'استلمت منك' : 'سلمتك'} مبلغ ${_money(l.amount)} جنيه',
      if (l.description != null && l.description!.trim().isNotEmpty) 'ملاحظات: ${l.description!.trim()}',
      'الرصيد بعدها: ${_money(l.balanceAfter.abs())} جنيه (${balanceDescription(l.balanceAfter)})',
    ],
    '',
    '────────────',
    '💰 ملخص الحساب',
    '',
    'إجمالي ما سلمتك: ${_money(gave)} جنيه',
    'إجمالي ما استلمته منك: ${_money(received)} جنيه',
    '',
    '💵 الرصيد الحالي: ${_money(current.abs())} جنيه (${balanceDescription(current)})',
    '',
    'يرجى مراجعة البيانات وإبلاغي إذا كان هناك اختلاف.',
  ].join('\n');
}
