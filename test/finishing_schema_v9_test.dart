import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';

void main() {
  test('fresh v9 database creates finishing tables without existing financial postings', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'finishing_%'",
    ).get();
    final names = tables.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(<String>[
      'finishing_projects',
      'finishing_trades',
      'finishing_events',
      'finishing_cost_details',
      'finishing_allocations',
      'finishing_cash_legs',
      'finishing_audit',
      'finishing_attachments',
    ]));
    final transactions = await db.customSelect('SELECT count(*) AS n FROM transactions').getSingle();
    expect(transactions.read<int>('n'), 0);
  });

  test('finishing cost amounts must be positive', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO finishing_projects(id, person_sync_id, name, start_date, created_at, updated_at) "
      "VALUES ('p1', 'person-1', 'Test project', '2026-11-09', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO finishing_trades(id, project_id, label) VALUES ('trade-1','p1','Plumbing')",
    );
    await db.customStatement(
      "INSERT INTO finishing_events(id, project_id, kind, occurred_at, created_at) "
      "VALUES ('event-1','p1','cost','2026-11-09',1)",
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO finishing_cost_details(event_id,trade_id,cost_type,amount_piasters,description) "
        "VALUES ('event-1','trade-1','materials',0,'Invalid')",
      ),
      throwsA(isA<Exception>()),
    );
  });
}
