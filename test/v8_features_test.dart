import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/core/db/tables.dart';
import 'package:expense_tracker_flutter/core/security/secure_storage.dart';
import 'package:expense_tracker_flutter/core/settings/settings_state.dart';
import 'package:expense_tracker_flutter/features/accounts/data/account_repository.dart';
import 'package:expense_tracker_flutter/features/settings/data/general_reminders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('salary is recorded once a month on or after the salary day', () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedIfNeeded(db);
    await ensureTrustCategory(db);
    await migrateToAccounts(db);
    const s = SettingsState(salaryDay: 25, salaryAmount: 20000);
    expect(await recordSalaryIfDue(db, s, now: DateTime(2026, 10, 20)), isFalse, reason: 'before payday');
    expect(await recordSalaryIfDue(db, s, now: DateTime(2026, 10, 25)), isTrue);
    expect(await recordSalaryIfDue(db, s, now: DateTime(2026, 10, 28)), isFalse, reason: 'already this month');
    expect(await recordSalaryIfDue(db, s, now: DateTime(2026, 11, 26)), isTrue);
    final income = (await db.select(db.transactions).get()).where((t) => t.type == TransactionType.income).toList();
    expect(income.map((t) => t.date), [DateTime(2026, 10, 25), DateTime(2026, 11, 25)]);
    expect(income.first.amount, 20000);
    final cash = (await AccountRepository(db).watchAccounts().first).first;
    expect(cash.balance, 40000);
    expect(await recordSalaryIfDue(db, const SettingsState(salaryDay: 25), now: DateTime(2026, 12, 26)), isFalse, reason: 'no amount');
    await db.close();
  });

  test('security answers ignore case, spaces and Arabic letter variants', () {
    expect(SecureStorageService.normalizeAnswer('  أحمد   علي '), SecureStorageService.normalizeAnswer('احمد علي'));
    expect(SecureStorageService.normalizeAnswer('مدرسة النيل'), SecureStorageService.normalizeAnswer('مدرسه النيل'));
    expect(SecureStorageService.normalizeAnswer('Cairo'), 'cairo');
  });

  test('sections: switched off implies hidden', () {
    const s = SettingsState(disabledModules: ['cars'], hiddenModules: ['budgets']);
    expect(s.moduleEnabled('cars'), isFalse);
    expect(s.moduleShown('cars'), isFalse);
    expect(s.moduleEnabled('budgets'), isTrue);
    expect(s.moduleShown('budgets'), isFalse);
    expect(s.moduleShown('associations'), isTrue);
  });
}
