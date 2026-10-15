import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/database_provider.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/features/accounts/data/account_repository.dart';
import 'package:expense_tracker_flutter/features/cars/data/car_repository.dart';
import 'package:expense_tracker_flutter/features/cars/presentation/cars_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<void> pumpFor(WidgetTester tester, [int n = 10]) async {
    for (var i = 0; i < n; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('fuel expense: litres (Arabic digits) → amount → save', (tester) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3;
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    late int carId;
    await tester.runAsync(() async {
      await seedIfNeeded(db);
      await ensureTrustCategory(db);
      await migrateToAccounts(db);
      carId = await CarRepository(db).createCar(name: 'عربيتي', brand: 'Toyota', modelYear: 2022);
    });
    final router = GoRouter(initialLocation: '/cars/$carId', routes: [
      GoRoute(path: '/cars/:id', builder: (_, s) => CarDetailsScreen(carId: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/cars/:id/expense', builder: (_, s) => CarExpenseFormScreen(carId: int.parse(s.pathParameters['id']!))),
    ]);
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('ar'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('ar'),
      saveLocale: false,
      child: ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: Builder(
          builder: (context) => MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
          ),
        ),
      ),
    ));
    await pumpFor(tester);
    router.push('/cars/$carId/expense');
    await pumpFor(tester);

    // Litres typed with an Arabic keyboard.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), '٤٠'); // litres (odometer, litres, amount)
    await pumpFor(tester, 3);
    await tester.enterText(fields.at(0), '٤١٢٠٠');
    await pumpFor(tester, 3);
    await tester.tap(find.byIcon(Icons.save_rounded));
    await pumpFor(tester, 15);

    // Back on the car screen with the new fuel expense listed.
    expect(find.byType(CarExpenseFormScreen), findsNothing, reason: 'form closed after saving');
    expect(find.textContaining('41,200'), findsWidgets);
    expect(find.textContaining('40 لتر'), findsWidgets);
    expect(find.textContaining('770'), findsWidgets); // 40 L × 19.25
    // Dismiss the "saved" snackbar so its timer does not outlive the test.
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).removeCurrentSnackBar();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    // Drift closes stream queries with a zero-length timer once their subscriptions are cancelled.
    await pumpFor(tester, 3);
    // The in-memory database is not closed: its stream queries were opened inside the test's
    // fake-async zone and closing would wait on them forever.
  });
}
