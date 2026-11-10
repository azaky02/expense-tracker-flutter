import 'package:expense_tracker_flutter/core/db/tables.dart';
import 'package:expense_tracker_flutter/features/finishing/domain/finishing_rules.dart';
import 'package:expense_tracker_flutter/features/finishing/presentation/project_whatsapp.dart';
import 'package:expense_tracker_flutter/features/people/presentation/whatsapp_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('people notice follows the agreed layout', () {
    final m = buildLedgerWhatsAppMessage(
      personName: 'أحمد هلال',
      kind: LedgerKind.advance,
      direction: LedgerDirection.received,
      amount: 1,
      date: DateTime(2026, 11, 9),
      previousBalance: 2500,
      currentBalance: 2499,
      confirmed: true,
    );
    for (final line in [
      'أهلاً أستاذ أحمد هلال 👋',
      'تم تسجيل معاملة مالية بيننا:',
      '📌 نوع المعاملة: عهدة',
      '💵 مبلغ المعاملة: 1.00 جنيه',
      '📅 التاريخ: 09/11/2026',
      '📝 تفاصيل المعاملة:',
      'استلمت منك مبلغ 1.00 جنيه كعهدة.',
      '💰 ملخص الحساب',
      'الرصيد السابق: 2500.00 جنيه',
      'قيمة المعاملة: 1.00 جنيه',
      '💵 الرصيد الحالي: 2499.00 جنيه',
    ]) {
      expect(m, contains(line));
    }
  });

  test('project notice names the project and the balance side', () {
    final m = buildProjectWhatsAppMessage(
      clientName: 'محمد',
      projectName: 'فيلا محمد',
      kind: FinishingKind.cost,
      amount: 8000,
      date: DateTime(2026, 11, 9),
      previousBalance: 5000,
      currentBalance: -3000,
      trade: 'كهرباء',
    );
    expect(m, contains('🏗️ المشروع: فيلا محمد'));
    expect(m, contains('(بند كهرباء)'));
    expect(m, contains('💵 الرصيد الحالي: 3000.00 جنيه (مستحق لي عندك)'));
  });
}
