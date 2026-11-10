import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_flutter/core/db/tables.dart';
import 'package:expense_tracker_flutter/features/people/presentation/whatsapp_message.dart';

void main() {
  test('Egyptian local and international WhatsApp numbers', () {
    expect(whatsAppDigits('01155508000'), '201155508000');
    expect(whatsAppDigits('+20 115 550 8000'), '201155508000');
    expect(whatsAppDigits('00201155508000'), '201155508000');
    expect(whatsAppDigits('+971501234567'), '971501234567');
    expect(whatsAppDigits('123'), isNull);
  });

  test('Arabic WhatsApp message uses actual newlines and describes balance direction', () {
    final message = buildLedgerWhatsAppMessage(
      personName: 'Ahmed Helal',
      kind: LedgerKind.advance,
      direction: LedgerDirection.received,
      amount: 1,
      date: DateTime(2026, 11, 9),
      previousBalance: -2500,
      currentBalance: -2501,
      confirmed: true,
    );
    expect(message, contains('استلمت منك مبلغ 1.00'));
    expect(message, contains('الرصيد السابق: 2500.00 جنيه (مستحق لك عندي)'));
    expect(message, contains('الرصيد الحالي: 2501.00 جنيه (مستحق لك عندي)'));
    expect(message, contains('09/11/2026'));
    expect(message, contains('\n'));
    expect(message, isNot(contains(r'\\n')));
  });

  test('pending entries do not falsely change confirmed balance', () {
    final message = buildLedgerWhatsAppMessage(
      personName: 'Ahmed',
      kind: LedgerKind.settlement,
      direction: LedgerDirection.gave,
      amount: 10,
      date: DateTime(2026, 11, 9),
      previousBalance: -100,
      currentBalance: -100,
      confirmed: false,
    );
    expect(message, contains('قيد التأكيد'));
    expect(message, contains('الرصيد الحالي: 100.00'));
  });
}
