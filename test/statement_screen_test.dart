import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/database_provider.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/core/db/tables.dart';
import 'package:expense_tracker_flutter/features/people/data/ledger_repository.dart';
import 'package:expense_tracker_flutter/features/people/presentation/statement_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<void> pumpFor(WidgetTester tester, [int n = 10]) async {
    for (var i = 0; i < n; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('person statement shows entries with running balance', (tester) async {
    tester.view.physicalSize = const Size(1170, 2600);
    tester.view.devicePixelRatio = 3;
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    late int pid;
    await tester.runAsync(() async {
      await seedIfNeeded(db);
      final repo = LedgerRepository(db);
      pid = await db.into(db.people).insert(PeopleCompanion.insert(name: 'أحمد هلال'));
      await repo.createEntry(personId: pid, kind: LedgerKind.advance, direction: LedgerDirection.gave, amount: 2500, date: DateTime(2026, 11, 1), signedIn: false);
      await repo.createEntry(personId: pid, kind: LedgerKind.advance, direction: LedgerDirection.received, amount: 1, date: DateTime(2026, 11, 9), signedIn: false);
    });
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
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: StatementScreen(personId: pid),
            ),
          ),
        ),
      ),
    );
    await pumpFor(tester);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('2,499'), findsWidgets);
    // WhatsApp button: no number saved → a clear message instead of silence.
    await tester.tap(find.byIcon(Icons.chat_outlined));
    await pumpFor(tester, 3);
    expect(find.textContaining('مفيش رقم واتساب'), findsOneWidget);
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).removeCurrentSnackBar();
    await tester.pumpWidget(const SizedBox());
    await pumpFor(tester, 3);
  });
}
