import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/features/accounts/data/account_repository.dart';
import 'package:expense_tracker_flutter/features/finishing/data/finishing_export.dart';
import 'package:expense_tracker_flutter/features/finishing/data/finishing_repository.dart';
import 'package:expense_tracker_flutter/features/finishing/domain/finishing_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Writes a sample project report to test_out/ for a visual check (not a real assertion).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  test('sample finishing PDF', () async {
    final ar = (jsonDecode(File('assets/translations/ar.json').readAsStringSync()) as Map<String, dynamic>);
    String tr(String key, {Map<String, String>? args}) {
      Object? v = ar;
      for (final k in key.split('.')) {
        v = v is Map ? v[k] : null;
      }
      return v is String ? v : key;
    }

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedIfNeeded(db);
    await migrateToAccounts(db);
    final cash = (await AccountRepository(db).watchAccounts().first).first.account.id;
    final repo = FinishingRepository(db);
    final pid = await repo.createProject(clientName: 'أحمد محمد', name: 'شقة المعادي', startDate: DateTime(2026, 10, 1), plannedBudget: 15000000, trades: ['كهرباء', 'سباكة', 'نقاشة']);
    final t = (await repo.loadProject(pid))!.trades;
    var n = 0;
    Future<void> rec(FinishingKind k, int egp, {int c = 0, int p = 0, int? trade, CostType? type, String? desc, String? who, int day = 1}) => repo.record(
      eventId: 'e${n++}', projectId: pid, kind: k, amount: egp * 100, tradeId: trade, costType: type, description: desc, beneficiary: who, date: DateTime(2026, 10, day), accountId: cash);
    await rec(FinishingKind.clientAdvance, 50000, desc: 'دفعة أولى', day: 2);
    await rec(FinishingKind.cost, 8000, c: 8000, trade: t[0].id, type: CostType.materials, desc: 'سلك وعلب', day: 4);
    await rec(FinishingKind.cost, 5000, p: 5000, trade: t[1].id, type: CostType.materials, desc: 'مواسير', day: 6);
    await rec(FinishingKind.cost, 15000, c: 10000, p: 5000, trade: t[2].id, type: CostType.labor, desc: 'مصنعية نقاشة', who: 'معلم سيد', day: 9);
    await rec(FinishingKind.clientAdvance, 10000, desc: 'دفعة تانية', day: 15);
    final d = (await repo.loadProject(pid))!;
    File('test_out/finishing_sample.pdf').writeAsBytesSync(await buildProjectPdf(d, tr, 'ar'));
    await db.close();
  });
}
