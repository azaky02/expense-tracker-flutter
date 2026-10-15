import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/core/db/tables.dart';
import 'package:expense_tracker_flutter/features/accounts/data/account_repository.dart';
import 'package:expense_tracker_flutter/features/cars/data/car_repository.dart';
import 'package:expense_tracker_flutter/features/installments/data/installment_repository.dart';
import 'package:expense_tracker_flutter/features/settings/data/general_reminders.dart';
import 'package:expense_tracker_flutter/features/stats/data/stats_period.dart';
import 'package:expense_tracker_flutter/features/transactions/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('current period follows the salary day', () {
    final plain = currentPeriod(DateTime(2026, 10, 14), 0);
    expect((plain.from, plain.to), (DateTime(2026, 10, 1), DateTime(2026, 10, 31)));
    // Salary on the 25th: on Oct 14 the financial month is Sep 25 – Oct 24.
    final before = currentPeriod(DateTime(2026, 10, 14), 25);
    expect((before.from, before.to), (DateTime(2026, 9, 25), DateTime(2026, 10, 24)));
    final after = currentPeriod(DateTime(2026, 10, 27), 25);
    expect((after.from, after.to), (DateTime(2026, 10, 25), DateTime(2026, 11, 24)));
    // Day 31 is clamped in short months.
    final feb = currentPeriod(DateTime(2027, 3, 5), 31);
    expect((feb.from, feb.to), (DateTime(2027, 2, 28), DateTime(2027, 3, 30)));
  });

  test('salary reminders and reminder times', () {
    final days = nextSalaryDays(31, DateTime(2026, 10, 14));
    expect(days.take(3), [DateTime(2026, 10, 31, 10), DateTime(2026, 11, 30, 10), DateTime(2026, 12, 31, 10)]);
    expect(days, hasLength(12));
    expect(parseTime('21:30'), (21, 30));
    expect(parseTime(''), isNull);
    expect(parseTime('25:00'), isNull);
  });

  test('statistics for a period: income, expenses, car, installments; car expense edit', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedIfNeeded(db);
    await ensureTrustCategory(db);
    await migrateToAccounts(db);
    final cash = (await AccountRepository(db).watchAccounts().first).first.account.id;
    final cats = {for (final c in await db.select(db.categories).get()) c.syncId: c.id};
    Future<void> tx(TransactionType type, double amount, String syncId, DateTime date) => db.into(db.transactions).insert(
        TransactionsCompanion.insert(
            amount: amount, type: type, categoryId: cats[syncId]!, paymentMethodType: PaymentMethodType.cash, date: date, accountId: Value(cash)));
    await tx(TransactionType.income, 20000, 'seed-cat-10', DateTime(2026, 10, 1)); // راتب
    await tx(TransactionType.expense, 500, 'seed-cat-0', DateTime(2026, 10, 3)); // أكل و شرب
    await tx(TransactionType.expense, 999, 'seed-cat-0', DateTime(2026, 9, 30)); // outside the period

    final cars = CarRepository(db);
    final carId = await cars.createCar(name: 'عربيتي', brand: 'Kia', modelYear: 2020);
    final expenseId = await cars.addExpense(CarExpenseInput(
        carId: carId, categoryId: cats['seed-cat-car-fuel']!, amount: 700, accountId: cash, date: DateTime(2026, 10, 5), odometer: 1000, liters: 35, note: 'فل'));

    final inst = InstallmentRepository(db);
    await inst.create(InstallmentsCompanion.insert(
        title: 'تلاجة', provider: 'valU', totalAmount: 6000, installmentAmount: 1000, months: 6, dueDay: 10, startMonth: DateTime(2026, 10)));
    final plan = (await inst.loadAll()).single.plan;
    await inst.markPaid(plan, 1, amount: 1000, paidAt: DateTime(2026, 10, 9), accountId: cash);

    Future<StatsData> load(StatsPeriod p) async => StatsData(
          period: p,
          transactions: await TransactionRepository(db).watchList(TransactionFilters(from: p.from, to: p.to)).first,
          cars: await cars.loadCars(),
          installments: await inst.loadAll(),
        );
    var d = await load(StatsPeriod.month(DateTime(2026, 10)));
    expect(d.totalIncome, 20000);
    expect(d.totalExpense, 500 + 700 + 1000, reason: 'food + fuel + installment paid as an expense');
    expect(d.carTotal, 700);
    expect(d.installmentsPaid, 1000);
    expect(d.installmentsDue, 0, reason: 'only installment 1 falls in October and it is paid');
    expect(d.byMainCategory.map((c) => c.$1), containsAll(['أكل و شرب', 'السيارة', 'أقساط']));
    expect(d.trend, hasLength(31));
    expect(d.trend[2].$3, 500);

    // Custom period with a main-category filter.
    final car = (await (db.select(db.categories)..where((c) => c.syncId.equals('seed-cat-car'))).getSingle()).id;
    final family = {for (final c in await db.select(db.categories).get()) if (c.id == car || c.parentCategoryId == car) c.id};
    final filtered = StatsData(
      period: StatsPeriod(kind: StatsPeriodKind.custom, from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 31), categoryId: car),
      transactions: await TransactionRepository(db).watchList(TransactionFilters(from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 31))).first,
      cars: await cars.loadCars(),
      installments: await inst.loadAll(),
      categoryIds: family,
    );
    expect(filtered.totalExpense, 700);

    // November: installment 2 is due and unpaid.
    d = await load(StatsPeriod.month(DateTime(2026, 11)));
    expect(d.installmentsDue, 1000);
    expect(d.installmentLines.single.paid, isFalse);

    // Editing the car expense updates both rows; the user note keeps its own text.
    final (e, t) = (await cars.loadExpense(expenseId))!;
    expect(CarRepository.userNote(t.note, 'عربيتي'), 'فل');
    await cars.updateExpense(
        e.id,
        CarExpenseInput(
            carId: carId, categoryId: cats['seed-cat-car-fuel']!, amount: 800, accountId: cash, date: DateTime(2026, 10, 6), odometer: 1010, liters: 40, note: 'فل التانك'));
    final (e2, t2) = (await cars.loadExpense(expenseId))!;
    expect(t2.amount, 800);
    expect(t2.date, DateTime(2026, 10, 6));
    expect(e2.odometer, 1010);
    expect(e2.liters, 40);
    expect(CarRepository.userNote(t2.note, 'عربيتي'), 'فل التانك');
    await db.close();
  });
}
