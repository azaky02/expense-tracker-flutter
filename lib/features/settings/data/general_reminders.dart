import 'package:drift/drift.dart' show Value;
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/db/seed.dart';
import '../../../core/db/tables.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../core/settings/settings_state.dart';
import '../../installments/data/installment_reminders.dart';

const _dailyBase = 7700;
const _salaryBase = 7600;
const _salaryCount = 12;

/// "HH:mm" → (hour, minute), or null.
(int, int)? parseTime(String s) {
  final p = s.split(':');
  if (p.length != 2) return null;
  final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
  return (h, m);
}

/// The next [count] salary days at 10:00 (the day is clamped to short months).
List<DateTime> nextSalaryDays(int day, DateTime now, {int count = _salaryCount}) {
  final out = <DateTime>[];
  for (var i = 0; out.length < count && i < count + 2; i++) {
    final m = DateTime(now.year, now.month + i);
    final last = DateTime(m.year, m.month + 1, 0).day;
    final d = DateTime(m.year, m.month, day.clamp(1, last), 10);
    if (d.isAfter(now)) out.add(d);
  }
  return out;
}

Future<void> rescheduleGeneralReminders(SettingsState s) async {
  final n = InstallmentReminders.instance;
  await n.cancelIds([for (var i = 0; i < 3; i++) _dailyBase + i, for (var i = 0; i < _salaryCount; i++) _salaryBase + i]);
  if (s.dailyReminder) {
    for (var i = 0; i < s.reminderTimes.length && i < 3; i++) {
      final t = parseTime(s.reminderTimes[i]);
      if (t == null) continue;
      await n.scheduleDaily(
        id: _dailyBase + i,
        hour: t.$1,
        minute: t.$2,
        title: 'reminders.dailyTitle'.tr(),
        body: 'reminders.dailyBody'.tr(),
      );
    }
  }
  if (s.salaryDay > 0) {
    final days = nextSalaryDays(s.salaryDay, DateTime.now());
    for (var i = 0; i < days.length; i++) {
      await n.scheduleAt(id: _salaryBase + i, when: days[i], title: 'reminders.salaryTitle'.tr(), body: 'reminders.salaryBody'.tr());
    }
  }
}

/// Re-schedules when the reminder settings change (watched by the app root).
final generalRemindersProvider = Provider<void>((ref) {
  ref.listen(settingsProvider.select((s) => (s.loaded, s.dailyReminder, s.reminderTimes.join(','), s.salaryDay)), (_, next) {
    if (next.$1) rescheduleGeneralReminders(ref.read(settingsProvider));
  }, fireImmediately: true);
});

const _lastSalaryKey = 'salary.lastRecordedMonth';

/// On or after the salary day, records the monthly salary once as income on the cash account
/// (under "راتب"). Returns true when it recorded one.
Future<bool> recordSalaryIfDue(AppDatabase db, SettingsState s, {DateTime? now}) async {
  if (s.salaryDay <= 0 || s.salaryAmount <= 0) return false;
  final today = now ?? DateTime.now();
  final last = DateTime(today.year, today.month + 1, 0).day;
  final payDay = DateTime(today.year, today.month, s.salaryDay.clamp(1, last));
  if (today.isBefore(payDay)) return false;
  final prefs = await SharedPreferences.getInstance();
  final key = '${today.year}-${today.month}';
  if (prefs.getString(_lastSalaryKey) == key) return false;
  final category = await seededCategoryId(db, 'seed-cat-10'); // راتب
  final cash = await (db.select(db.accounts)..where((a) => a.type.equalsValue(AccountType.cash))).get();
  if (category == null) return false;
  await db.into(db.transactions).insert(TransactionsCompanion.insert(
        amount: s.salaryAmount,
        type: TransactionType.income,
        categoryId: category,
        paymentMethodType: PaymentMethodType.cash,
        date: payDay,
        note: const Value('راتب – تسجيل تلقائي'),
        accountId: Value(cash.firstOrNull?.id),
      ));
  await prefs.setString(_lastSalaryKey, key);
  return true;
}

final salaryIncomeProvider = Provider<void>((ref) {
  ref.listen(settingsProvider.select((s) => (s.loaded, s.salaryDay, s.salaryAmount)), (_, next) {
    if (next.$1) recordSalaryIfDue(ref.read(databaseProvider), ref.read(settingsProvider));
  }, fireImmediately: true);
});
