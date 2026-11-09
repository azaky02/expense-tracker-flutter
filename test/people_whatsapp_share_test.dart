import 'package:drift/native.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/features/people/data/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('separate WhatsApp number persists and can switch to phone', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LedgerRepository(db);
    final id = await repo.createPerson(name: 'Test', phone: '+201001112233');
    await repo.setWhatsAppNumber(id, usePhone: false, number: '+201099988877');
    expect(await repo.whatsAppNumber(id), '+201099988877');
    expect(await repo.usesPhoneForWhatsApp(id), isFalse);
    await repo.setWhatsAppNumber(id, usePhone: true);
    expect(await repo.whatsAppNumber(id), '+201001112233');
    expect(await repo.usesPhoneForWhatsApp(id), isTrue);
    await repo.updatePerson(id, name: 'Test', phone: '+201055566677');
    expect(await repo.whatsAppNumber(id), '+201055566677');
    await repo.setWhatsAppNumber(id, usePhone: false);
    expect(await repo.whatsAppNumber(id), isNull);
  });
}
