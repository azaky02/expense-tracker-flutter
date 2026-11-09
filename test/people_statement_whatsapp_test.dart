import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_flutter/features/people/presentation/whatsapp_message.dart';

void main() {
  test('empty confirmed statement clearly shows zero balance', () {
    final message = buildStatementWhatsAppMessage(personName: 'Ahmed', lines: []);
    expect(message, contains('أهلاً Ahmed'));
    expect(message, contains('عدد المعاملات: 0'));
    expect(message, contains('الرصيد الحالي: 0.00 جنيه — الحساب متسوي'));
    expect(message, contains('المعاملات المؤكدة فقط'));
    expect(message, isNot(contains(r'\\n')));
  });
}
