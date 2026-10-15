// Renders the main screens with demo data into PNGs (test_screens/goldens/) for visual review,
// because the emulator cannot run on the dev machine. Not part of the normal test suite:
//   flutter test test_screens/screens_test.dart --update-goldens
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:expense_tracker_flutter/app.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/database_provider.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/core/db/tables.dart';
import 'package:expense_tracker_flutter/core/router/app_router.dart';
import 'package:expense_tracker_flutter/core/sync/sync_controller.dart';
import 'package:expense_tracker_flutter/core/theme/app_theme.dart';
import 'package:expense_tracker_flutter/features/accounts/data/account_repository.dart';
import 'package:expense_tracker_flutter/features/budgets/data/budget_repository.dart';
import 'package:expense_tracker_flutter/features/cars/data/car_repository.dart';
import 'package:expense_tracker_flutter/features/installments/data/installment_repository.dart';
import 'package:expense_tracker_flutter/features/payment_methods/data/card_repository.dart';
import 'package:expense_tracker_flutter/features/people/data/ledger_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedOutSync extends SyncController {
  @override
  SyncState build() => const SyncState(loaded: true);
}

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.view(File(f).readAsBytesSync().buffer)));
  }
  await loader.load();
}

Future<void> _demoData(AppDatabase db) async {
  await seedIfNeeded(db);
  await ensureTrustCategory(db);
  await migrateToAccounts(db);
  final now = DateTime.now();
  DateTime day(int back) => DateTime(now.year, now.month, now.day).subtract(Duration(days: back));
  final accounts = AccountRepository(db);
  final cash = (await accounts.watchAccounts().first).first.account.id;
  await (db.update(db.accounts)..where((a) => a.id.equals(cash))).write(const AccountsCompanion(openingBalance: Value(6000)));
  final cib = await accounts.create(name: 'CIB', type: AccountType.bank, openingBalance: 2000);
  await CardRepository(db).create(
      bankId: 1, cardType: CardType.visa, cardCategory: CardCategory.credit, nickname: 'Credit Card', last4Digits: '4321', dueDateDay: now.day + 3 > 28 ? 28 : now.day + 3);
  final card = (await (db.select(db.accounts)..where((a) => a.cardId.isNotNull())).getSingle()).id;
  final cats = {for (final c in await db.select(db.categories).get()) c.name: c.id};
  Future<void> tx(TransactionType type, double amount, String cat, int account, int back, {String? who, int? to}) =>
      db.into(db.transactions).insert(TransactionsCompanion.insert(
          amount: amount, type: type, categoryId: cats[cat]!, paymentMethodType: PaymentMethodType.cash, date: day(back),
          accountId: Value(account), toAccountId: Value(to), beneficiaryName: Value(who)));
  await tx(TransactionType.income, 50000, 'راتب', cib, 6);
  await tx(TransactionType.expense, 1250, 'أكل و شرب', cash, 0, who: 'Carrefour');
  await tx(TransactionType.expense, 800, 'بنزين', cash, 0, who: 'Wataniya');
  await tx(TransactionType.expense, 600, 'فواتير', cib, 1, who: 'WE Internet');
  await tx(TransactionType.expense, 6000, 'ترفيه', card, 2);
  await tx(TransactionType.expense, 3100, 'مواصلات عامة', cash, 3);
  await tx(TransactionType.transfer, 5000, 'تحويل', cib, 1, to: cash);
  final ledger = LedgerRepository(db);
  final ahmed = await ledger.createPerson(name: 'أحمد');
  await ledger.createEntry(personId: ahmed, kind: LedgerKind.loan, direction: LedgerDirection.received, amount: 100000, date: day(20));
  await ledger.createEntry(personId: ahmed, kind: LedgerKind.settlement, direction: LedgerDirection.gave, amount: 20000, date: day(12));
  await ledger.createEntry(personId: ahmed, kind: LedgerKind.settlement, direction: LedgerDirection.gave, amount: 15000, date: day(4));
  final mohamed = await ledger.createPerson(name: 'محمد');
  await ledger.createEntry(personId: mohamed, kind: LedgerKind.loan, direction: LedgerDirection.gave, amount: 15000, date: day(8));
  await ledger.createPerson(name: 'سامي');
  final plans = InstallmentRepository(db);
  final fridge = await plans.create(InstallmentsCompanion.insert(
      title: 'تلاجة', provider: 'valU', totalAmount: 24000, installmentAmount: 2000, months: 12, dueDay: (now.day + 3).clamp(1, 28),
      startMonth: DateTime(now.year, now.month - 2)));
  final fridgePlan = (await plans.loadAll()).firstWhere((p) => p.plan.id == fridge).plan;
  await plans.markPaid(fridgePlan, 1, amount: 2000, accountId: cash);
  await plans.markPaid(fridgePlan, 2, amount: 2000, accountId: cash);
  await plans.create(InstallmentsCompanion.insert(
      title: 'موبايل', provider: 'بنك مصر', totalAmount: 18000, installmentAmount: 1500, months: 12, dueDay: 25, startMonth: DateTime(now.year, now.month)));
  final cars = CarRepository(db);
  final carId = await cars.createCar(name: 'عربيتي', brand: 'تويوتا كورولا', modelYear: 2022);
  final fuelCat = (await seededCategoryId(db, 'seed-cat-car-fuel'))!;
  final serviceCat = (await seededCategoryId(db, 'seed-cat-car-service'))!;
  await cars.addExpense(CarExpenseInput(carId: carId, categoryId: fuelCat, amount: 770, accountId: cash, date: day(9), odometer: 41200, liters: 40, fuelTypeId: 2, pricePerLiter: 19.25, latitude: 30.03, longitude: 31.47, beneficiary: 'وطنية'));
  await cars.addExpense(CarExpenseInput(carId: carId, categoryId: serviceCat, amount: 1850, accountId: cib, date: day(5), odometer: 41500));
  await cars.addExpense(CarExpenseInput(carId: carId, categoryId: fuelCat, amount: 673.75, accountId: cash, date: day(1), odometer: 41720, liters: 35, fuelTypeId: 2, pricePerLiter: 19.25, latitude: 30.04, longitude: 31.48, beneficiary: 'موبيل'));
  final oilCat = (await seededCategoryId(db, 'seed-cat-car-oil'))!;
  await cars.addExpense(CarExpenseInput(carId: carId, categoryId: oilCat, amount: 950, accountId: cash, date: day(120), odometer: 33100));
  for (final (back, odo, liters, st) in [(60, 38200, 38.0, 'وطنية'), (45, 38700, 41.0, 'توتال'), (30, 39250, 40.0, 'وطنية'), (20, 39800, 37.0, 'موبيل'), (14, 40400, 42.0, 'توتال')]) {
    await cars.addExpense(CarExpenseInput(carId: carId, categoryId: fuelCat, amount: liters * 19.25, accountId: cash, date: day(back), odometer: odo, liters: liters, fuelTypeId: 2, pricePerLiter: 19.25, beneficiary: st));
  }
  final budgets = BudgetRepository(db);
  await budgets.setBudget(cats['أكل و شرب']!, 1500);
  await budgets.setBudget(cats['مواصلات']!, 4000);
  await budgets.setBudget(cats['ترفيه']!, 5000);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUpAll(() async {
    AppTheme.useGoogleFonts = false;
    const segoe = r'C:\Windows\Fonts\segoeui.ttf';
    const segoeBold = r'C:\Windows\Fonts\segoeuib.ttf';
    for (final family in ['Cairo', 'Inter', 'Roboto']) {
      await _loadFont(family, [segoe, segoeBold]);
    }
    await _loadFont('MaterialIcons', [r'C:\dev\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf']);
  });

  Future<void> shoot(WidgetTester tester, {required bool onboarded, required Map<String, String> shots, Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    SharedPreferences.setMockInitialValues({
      'settings.hasOnboarded': onboarded,
      'settings.userName': 'عمرو',
      'settings.userPhone': '01001234567',
      'settings.languageCode': 'ar',
    });
    await EasyLocalization.ensureInitialized();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    // ignore: avoid_print
    print('demo data...');
    await tester.runAsync(() => _demoData(db));
    // ignore: avoid_print
    print('demo data done');
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      syncControllerProvider.overrideWith(_SignedOutSync.new),
    ]);
    final key = GlobalKey();
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      // ignore: avoid_print
      print('FLUTTER ERROR: ' + d.exceptionAsString() + ' | ' + d.stack.toString().split(String.fromCharCode(10)).take(12).join(' || '));
      original?.call(d);
    };
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: EasyLocalization(
        supportedLocales: const [Locale('ar'), Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('ar'),
        saveLocale: false,
        child: UncontrolledProviderScope(container: container, child: const ExpenseTrackerApp()),
      ),
    ));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (final e in shots.entries) {
      container.read(routerProvider).go(e.value);
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump(const Duration(milliseconds: 60));
      }
      final ex = tester.takeException();
      // ignore: avoid_print
      if (ex != null) print('EXC on ${e.value}: $ex');
      // ignore: avoid_print
      print('shot ${e.key} scaffolds=${find.byType(Scaffold).evaluate().length} spinner=${find.byType(CircularProgressIndicator).evaluate().length} texts=${find.byType(Text).evaluate().length}');
      // The outermost Scaffold is the whole visible screen (shell with bottom bar, or the route).
      final target = find.byType(Scaffold).evaluate().isEmpty ? find.byKey(key) : find.byType(Scaffold).last;
      await expectLater(target, matchesGoldenFile('goldens/${e.key}.png'));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    container.dispose();
    // The in-memory database is left open: closing it waits forever on stream queries that were
    // started inside the test's fake-async zone.
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('auth screens', (tester) async {
    await shoot(tester, onboarded: false, shots: {'01_welcome': '/onboarding', '02_login': '/login', '03_register': '/register'});
  });

  testWidgets('main screens', (tester) async {
    await shoot(tester, onboarded: true, shots: {
      '05_home': '/home',
      '06_transactions': '/transactions',
      '08_add_expense': '/transactions/add',
      '09_filters': '/transactions/filters',
      '10_people': '/people',
      '11_person': '/people/1',
      '12_shared_tx': '/ledger/new?personId=1',
      '13_settlement': '/ledger/new?personId=1&kind=settlement',
      '14_accounts': '/accounts',
      '15_budgets': '/budgets',
      '16_reports': '/reports',
      '17_more': '/settings',
      '18_statement': '/people/1/statement',
      '19_security': '/security',
      '20_backup': '/backup',
    });
  });

  testWidgets('v5 screens', (tester) async {
    await shoot(tester, onboarded: true, shots: {
      '21_installments': '/installments',
      '22_installment': '/installments/1',
      '23_installment_form': '/installments/new',
      '24_cars': '/cars',
      '25_car': '/cars/1',
      '26_car_expense': '/cars/1/expense',
      '27_fuel': '/fuel-prices',
      '30_car_report': '/cars/1/report',
      '31_stats': '/stats',
      '32_reminders': '/reminders',
      '28_home_categories': '/home',
    });
  });

  testWidgets('setup screen', (tester) async {
    await shoot(tester, onboarded: false, shots: {'29_setup': '/setup', '01_welcome': '/onboarding'});
  });

  testWidgets('dark home', (tester) async {
    await shoot(
      tester,
      onboarded: true,
      shots: {'05_home_dark': '/home', '10_people_dark': '/people', '31_stats_dark': '/stats', '30_car_report_dark': '/cars/1/report'},
      brightness: Brightness.dark,
    );
  });

  // Keep ui import used for the image format on some SDKs.
  test('noop', () => expect(ui.ImageByteFormat.png, isNotNull));
}
