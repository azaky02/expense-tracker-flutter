import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/database_provider.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/features/accounts/data/account_repository.dart';
import 'package:expense_tracker_flutter/features/finishing/data/finishing_repository.dart';
import 'package:expense_tracker_flutter/features/finishing/domain/finishing_rules.dart';
import 'package:expense_tracker_flutter/features/finishing/presentation/finishing_screens.dart';
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

  testWidgets('projects → details → custody → mixed cost', (tester) async {
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3;
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    late int pid;
    await tester.runAsync(() async {
      await seedIfNeeded(db);
      await migrateToAccounts(db);
      pid = await FinishingRepository(db).createProject(clientName: 'أحمد', name: 'شقة أحمد', startDate: DateTime(2026, 11), trades: ['كهرباء']);
    });
    final router = GoRouter(
      initialLocation: '/finishing',
      routes: [
        GoRoute(path: '/finishing', builder: (_, _) => const FinishingProjectsScreen()),
        GoRoute(path: '/finishing/:id', builder: (_, s) => FinishingProjectScreen(id: int.parse(s.pathParameters['id']!))),
        GoRoute(
          path: '/finishing/:id/event/:kind',
          builder: (_, s) => FinishingEventFormScreen(projectId: int.parse(s.pathParameters['id']!), kind: FinishingKind.parse(s.pathParameters['kind']!)),
        ),
      ],
    );
    await tester.pumpWidget(
      EasyLocalization(
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
      ),
    );
    await pumpFor(tester);
    expect(find.text('شقة أحمد'), findsOneWidget);
    await tester.tap(find.text('شقة أحمد'));
    await pumpFor(tester);
    expect(find.text('الملخص'), findsOneWidget);

    // Receive 50,000 custody.
    await tester.tap(find.text('استلام من العميل').first);
    await pumpFor(tester);
    await tester.enterText(find.byType(TextField).first, '٥٠٠٠٠');
    await tester.tap(find.byIcon(Icons.save_rounded));
    await pumpFor(tester, 15);
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).removeCurrentSnackBar();

    // Cost 60,000 after receiving 50,000: the client owes me 10,000.
    await tester.tap(find.text('مصروف').first);
    await pumpFor(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, '60000');
    await pumpFor(tester, 3);
    await tester.enterText(find.widgetWithText(TextField, 'مثلًا: سلك وعلب كهرباء'), 'خامات');
    await pumpFor(tester, 3);
    expect(find.textContaining('10,000'), findsWidgets);
    await tester.tap(find.byIcon(Icons.save_rounded));
    await pumpFor(tester, 15);
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).removeCurrentSnackBar();

    final d = await tester.runAsync(() => FinishingRepository(db).loadProject(pid));
    expect((d!.balance.custody, d.balance.receivable, d.balance.cost), (0, 1000000, 6000000));

    // Movements tab lists both.
    await tester.tap(find.text('الحركات'));
    await pumpFor(tester);
    expect(find.textContaining('استلام من العميل'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await pumpFor(tester, 3);
  });
}
