import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/features/accounts/data/account_repository.dart';
import 'package:expense_tracker_flutter/features/cars/data/car_analytics.dart';
import 'package:expense_tracker_flutter/features/cars/data/car_repository.dart';
import 'package:expense_tracker_flutter/features/cars/presentation/car_report_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('consumption, best station, costs and oil-change status', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedIfNeeded(db);
    await ensureTrustCategory(db);
    await migrateToAccounts(db);
    final repo = CarRepository(db);
    final carId = await repo.createCar(name: 'عربيتي', brand: 'Toyota', modelYear: 2022, oilIntervalKm: 5000, oilIntervalMonths: 6);
    final fuel = (await seededCategoryId(db, fuelCategorySyncId))!;
    final oil = (await seededCategoryId(db, oilCategorySyncId))!;
    final cash = (await AccountRepository(db).watchAccounts().first).first.account.id;

    Future<void> fill(int day, int odo, double liters, String station) => repo.addExpense(CarExpenseInput(
          carId: carId,
          categoryId: fuel,
          amount: liters * 20,
          accountId: cash,
          date: DateTime(2026, 9, day),
          odometer: odo,
          liters: liters,
          pricePerLiter: 20,
          beneficiary: station,
        ));
    // Oil changed at 10,000 km on Sep 1.
    await repo.addExpense(CarExpenseInput(carId: carId, categoryId: oil, amount: 900, accountId: cash, date: DateTime(2026, 9, 1), odometer: 10000));
    await fill(1, 10000, 40, 'وطنية'); // first fill: no consumption yet
    await fill(8, 10500, 40, 'موبيل'); // 40 L over 500 km of Wataniya fuel → 8.0
    await fill(15, 11000, 35, 'وطنية'); // 35 L over 500 km of Mobil fuel → 7.0
    await fill(22, 11600, 39, 'وطنية'); // 39 L over 600 km of Wataniya fuel → 6.5

    final car = (await repo.loadCars()).single;
    final a = CarAnalytics(car, now: DateTime(2026, 10, 1));

    expect(a.segments, hasLength(3));
    expect(a.segments.map((s) => double.parse(s.litersPer100Km.toStringAsFixed(3))), [8.0, 7.0, 6.5]);
    expect(a.kmDriven, 1600);
    expect(a.avgLitersPer100Km, closeTo((40 + 35 + 39) / 1600 * 100, 1e-9));
    expect(a.totalSpent, 900 + (40 + 40 + 35 + 39) * 20);
    expect(a.fuelSpent, (40 + 40 + 35 + 39) * 20);
    expect(a.avgPricePerLiter, 20);
    expect(a.costPerKm, closeTo(a.totalSpent / 1600, 1e-9));

    // Wataniya: (40 + 39) / (500 + 600) = 7.18; Mobil: 35 / 500 = 7.0 → Mobil is best.
    expect(a.stations.map((s) => s.name), ['موبيل', 'وطنية']);
    expect(a.stations.first.litersPer100Km, closeTo(7.0, 1e-9));
    expect(a.lastVsAveragePercent, lessThan(0), reason: 'last fill-up was better than average');

    // Oil: due at 15,000 km or Mar 1; at 11,600 km → 3,400 km left, OK.
    final o = a.oil;
    expect(o.dueKm, 15000);
    expect(o.remainingKm, 3400);
    expect(o.dueDate, DateTime(2027, 3, 1));
    expect(o.level, MaintenanceLevel.ok);
    // Close to the interval by distance.
    final late = CarAnalytics(car, now: DateTime(2026, 10, 1));
    late.lastOdometer = 14200;
    expect(late.oil.level, MaintenanceLevel.soon);
    late.lastOdometer = 15100;
    expect(late.oil.level, MaintenanceLevel.overdue);
    // Close by time.
    expect(CarAnalytics(car, now: DateTime(2027, 2, 20)).oil.level, MaintenanceLevel.soon);

    final months = a.monthly();
    expect(months.last.$1, DateTime(2026, 10));
    expect(months[10].$2, a.fuelSpent);
    expect(months[10].$3, 900);
    expect(a.license.level, MaintenanceLevel.unknown);

    // Exports (labels are the keys themselves here).
    String t(String key, [Map<String, String>? args]) => args == null ? key : '$key ${args.values.join(' ')}';
    final pdf = await buildCarReportPdf(a, t, rtl: true, generatedAt: '2026-10-01');
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    final xlsx = buildCarReportXlsx(a, t, rtl: true);
    final zip = ZipDecoder().decodeBytes(xlsx);
    expect(zip.files.where((f) => f.name.startsWith('xl/worksheets/')), hasLength(5));
    final fillsSheet = String.fromCharCodes(zip.findFile('xl/worksheets/sheet2.xml')!.content);
    expect(fillsSheet, contains('<v>11600</v>'), reason: 'odometer of the last fill-up');
    if (const bool.fromEnvironment('WRITE_SAMPLES')) {
      // Real Arabic labels from the translation file.
      final ar = jsonDecode(File('assets/translations/ar.json').readAsStringSync()) as Map<String, dynamic>;
      String tr(String key, [Map<String, String>? args]) {
        dynamic v = ar;
        for (final part in key.split('.')) {
          v = v is Map ? v[part] : null;
        }
        var out = v is String ? v : key;
        args?.forEach((k, val) => out = out.replaceAll('{$k}', val));
        return out;
      }

      final arPdf = await buildCarReportPdf(a, tr, rtl: true, generatedAt: 'تاريخ الإصدار 2026/10/01');
      File('test_screens/out/car_report_sample.pdf').writeAsBytesSync(arPdf);
      File('test_screens/out/car_report_sample_ar.xlsx').writeAsBytesSync(buildCarReportXlsx(a, tr, rtl: true));
      File('test_screens/out/car_report_sample.xlsx').writeAsBytesSync(xlsx);
    }
    await db.close();
  });
}
