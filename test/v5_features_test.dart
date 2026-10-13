import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/core/db/tables.dart';
import 'package:expense_tracker_flutter/features/accounts/data/account_repository.dart';
import 'package:expense_tracker_flutter/features/cars/data/car_repository.dart';
import 'package:expense_tracker_flutter/features/installments/data/installment_reminders.dart';
import 'package:expense_tracker_flutter/features/installments/data/installment_repository.dart';
import 'package:expense_tracker_flutter/features/reports/data/report_export.dart';
import 'package:expense_tracker_flutter/features/transactions/data/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppDatabase> _db() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await seedIfNeeded(db);
  await ensureTrustCategory(db);
  await migrateToAccounts(db);
  return db;
}

ReportLabels _labels() => const ReportLabels(
      isRtl: true,
      locale: 'ar',
      title: 'تقرير مصروفي',
      period: 'الفترة',
      preparedFor: 'إعداد: عمرو',
      generatedAt: 'اليوم',
      summary: 'الملخص',
      income: 'الدخل',
      expense: 'المصروفات',
      net: 'الصافي',
      byCategory: 'حسب الفئة',
      share: 'النسبة',
      transactions: 'المعاملات',
      date: 'التاريخ',
      type: 'النوع',
      mainCategory: 'المصروف الرئيسي',
      subCategory: 'المصروف الفرعي',
      beneficiary: 'المستفيد',
      account: 'الحساب',
      amount: 'المبلغ',
      note: 'ملاحظات',
      typeNames: {TransactionType.expense: 'مصروف', TransactionType.income: 'دخل'},
      total: 'الإجمالي',
      currency: 'ج.م',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('seed adds the car category tree, installments category and fuel prices', () async {
    final db = await _db();
    final car = await seededCategoryId(db, 'seed-cat-car');
    final fuel = await (db.select(db.categories)..where((c) => c.syncId.equals('seed-cat-car-fuel'))).getSingle();
    expect(fuel.parentCategoryId, car);
    expect(await seededCategoryId(db, 'seed-cat-installments'), isNotNull);
    expect(await db.select(db.fuelTypes).get(), hasLength(4));
    // Idempotent.
    await ensureTrustCategory(db);
    expect(await db.select(db.fuelTypes).get(), hasLength(4));
    await db.close();
  });

  test('installment schedule clamps the due day and payments create an expense', () async {
    final db = await _db();
    final repo = InstallmentRepository(db);
    final id = await repo.create(InstallmentsCompanion.insert(
      title: 'تلاجة',
      provider: 'valU',
      totalAmount: 12000,
      installmentAmount: 1000,
      months: 12,
      dueDay: 31,
      startMonth: DateTime(2026, 1),
    ));
    var item = (await repo.loadAll()).single;
    expect(item.schedule, hasLength(12));
    expect(item.schedule[0].dueDate, DateTime(2026, 1, 31));
    expect(item.schedule[1].dueDate, DateTime(2026, 2, 28), reason: 'clamped to the last day of February');
    expect(item.schedule[11].dueDate, DateTime(2026, 12, 31));

    final cash = (await AccountRepository(db).watchAccounts().first).first.account.id;
    await repo.markPaid(item.plan, 1, amount: 1000, accountId: cash, paidAt: DateTime(2026, 1, 30));
    item = (await repo.loadAll()).single;
    expect(item.paidCount, 1);
    expect(item.remainingAmount, 11000);
    expect(item.nextDue!.number, 2);
    final tx = await db.select(db.transactions).get();
    expect(tx.single.amount, 1000);
    expect(tx.single.beneficiaryName, 'valU');

    await repo.unmarkPaid(item.schedule.first.payment!);
    expect(await db.select(db.transactions).get(), isEmpty);
    await repo.delete(id);
    expect(await repo.loadAll(), isEmpty);
    await db.close();
  });

  test('reminders: 5 days before, at 12:00 and 22:00, unpaid only, capped', () {
    final plan = Installment(
      id: 1,
      title: 'موبايل',
      provider: 'بنك',
      totalAmount: 3000,
      installmentAmount: 1000,
      months: 3,
      dueDay: 10,
      startMonth: DateTime(2026, 11),
      notes: null,
      remindersEnabled: true,
      createdAt: DateTime(2026, 10, 1),
    );
    final item = InstallmentWithSchedule(plan, [
      for (var n = 1; n <= 3; n++) InstallmentDue(number: n, dueDate: installmentDueDate(plan, n)),
    ]);
    final slots = upcomingReminderSlots([item], DateTime(2026, 11, 4, 8));
    // Installment 1 (Nov 10): Nov 5..10 → 12 slots; installment 2 (Dec 10): 12 more.
    expect(slots, hasLength(24));
    expect(slots.first.when, DateTime(2026, 11, 5, 12));
    expect(slots[1].when, DateTime(2026, 11, 5, 22));
    expect(slots[11].when, DateTime(2026, 11, 10, 22));
    expect(slots[12].due.number, 2);
    // Already past 12:00 on the due day → only the 22:00 one is left for it.
    final late = upcomingReminderSlots([item], DateTime(2026, 11, 10, 13));
    expect(late.first.when, DateTime(2026, 11, 10, 22));
    final off = InstallmentWithSchedule(plan.copyWith(remindersEnabled: false), item.schedule);
    expect(upcomingReminderSlots([off], DateTime(2026, 11, 4)), isEmpty);
  });

  test('car expense is a transaction plus odometer, litres and location', () async {
    final db = await _db();
    final repo = CarRepository(db);
    final carId = await repo.createCar(name: 'عربيتي', brand: 'Toyota', modelYear: 2022);
    final fuelCat = (await seededCategoryId(db, 'seed-cat-car-fuel'))!;
    final cash = (await AccountRepository(db).watchAccounts().first).first.account.id;
    final fuel92 = (await db.select(db.fuelTypes).get())[1];
    for (final (odo, liters, day) in [(10000, 40.0, 1), (10500, 35.0, 10)]) {
      await repo.addExpense(CarExpenseInput(
        carId: carId,
        categoryId: fuelCat,
        amount: liters * fuel92.pricePerLiter,
        accountId: cash,
        date: DateTime(2026, 10, day),
        odometer: odo,
        liters: liters,
        fuelTypeId: fuel92.id,
        pricePerLiter: fuel92.pricePerLiter,
        latitude: 30.0444,
        longitude: 31.2357,
      ));
    }
    final car = (await repo.loadCars()).single;
    expect(car.expenses, hasLength(2));
    expect(car.lastOdometer, 10500);
    expect(car.totalLiters, 75);
    expect(car.litersPer100Km, closeTo(7.0, 0.001)); // 35 L over 500 km
    expect(car.expenses.first.categoryPath, 'السيارة › بنزين');
    expect(car.expenses.first.expense.latitude, 30.0444);

    // The money side shows up in the normal transaction list with main › sub.
    final list = await TransactionRepository(db).watchList(const TransactionFilters()).first;
    expect(list.first.categoryPath, 'السيارة › بنزين');

    await repo.deleteCar(carId);
    expect(await db.select(db.transactions).get(), isEmpty);
    await db.close();
  });

  test('report exports: valid xlsx workbook and a PDF', () async {
    final db = await _db();
    final cats = {for (final c in await db.select(db.categories).get()) c.name: c.id};
    final cash = (await AccountRepository(db).watchAccounts().first).first.account.id;
    Future<void> tx(TransactionType type, double amount, String cat, String? who) => db.into(db.transactions).insert(
        TransactionsCompanion.insert(
            amount: amount,
            type: type,
            categoryId: cats[cat]!,
            paymentMethodType: PaymentMethodType.cash,
            date: DateTime(2026, 10, 5),
            accountId: Value(cash),
            beneficiaryName: Value(who),
            note: const Value('a < b & "c"')));
    await tx(TransactionType.income, 20000, 'راتب', null);
    await tx(TransactionType.expense, 800, 'بنزين', 'وطنية');
    await tx(TransactionType.expense, 1200, 'أكل و شرب', 'Carrefour');
    final list = await TransactionRepository(db).watchList(TransactionFilters(from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 31))).first;
    final data = ReportData(from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 31), userName: 'عمرو', transactions: list);
    expect(data.income, 20000);
    expect(data.expense, 2000);
    expect(data.byCategory.first.name, 'أكل و شرب');
    expect(data.byCategory.map((c) => c.name), contains('السيارة'), reason: 'sub-categories roll up to their main category');

    final xlsx = buildReportXlsx(data, _labels());
    final zip = ZipDecoder().decodeBytes(xlsx);
    final names = zip.files.map((f) => f.name).toSet();
    expect(names, containsAll(['[Content_Types].xml', 'xl/workbook.xml', 'xl/worksheets/sheet1.xml', 'xl/worksheets/sheet2.xml']));
    final sheet2 = String.fromCharCodes(zip.findFile('xl/worksheets/sheet2.xml')!.content);
    expect(sheet2, contains('rightToLeft="1"'));
    expect(sheet2, contains('a &lt; b &amp; &quot;c&quot;'));

    final pdf = await buildReportPdf(data, _labels());
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    if (const bool.fromEnvironment('WRITE_SAMPLES')) {
      File('test_screens/out/report_sample.pdf').writeAsBytesSync(pdf);
      File('test_screens/out/report_sample.xlsx').writeAsBytesSync(xlsx);
    }
    await db.close();
  });
}
