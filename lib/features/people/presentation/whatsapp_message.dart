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
String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String balanceDescription(double net) {
  if (net > 0.005) return 'مستحق لي عندك';
  if (net < -0.005) return 'مستحق لك عندي';
  return 'الحساب متسوي';
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
  final kindLabel = kind == LedgerKind.settlement ? 'تسوية' : 'عهدة';
  final pendingLabel = confirmed ? '' : '\n⏳ المعاملة قيد التأكيد؛ الرصيد المعروض للمستندات المؤكدة فقط.';
  return [
    '💰 إشعار معاملة مالية - مصروفي',
    '',
    'أهلاً $personName 👋',
    '',
    'تم تسجيل معاملة $kindLabel بيننا.',
    '💵 مبلغ المعاملة: ${_money(amount)} جنيه مصري',
    '📅 التاريخ: ${_date(date)}',
    '📝 التفاصيل: $action مبلغ ${_money(amount)} جنيه مصري ${kind == LedgerKind.settlement ? 'كتسوية' : 'كعهدة'}.',
    if (description != null && description.trim().isNotEmpty) 'ملاحظات: ${description.trim()}',
    '',
    '📊 ملخص الحساب (من وجهة نظر مُرسل الرسالة)',
    'الرصيد السابق: ${_money(previousBalance.abs())} جنيه — ${balanceDescription(previousBalance)}',
    'الرصيد الحالي: ${_money(currentBalance.abs())} جنيه — ${balanceDescription(currentBalance)}',
    if (!confirmed) pendingLabel.trim(),
    '',
    'يرجى مراجعة البيانات وإبلاغي إذا كان هناك اختلاف.',
    'تم إعداد الرسالة باستخدام تطبيق مصروفي.',
  ].join('\n');
}
