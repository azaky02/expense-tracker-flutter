import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/features/finishing/data/finishing_pending_event_repository.dart';
import 'package:expense_tracker_flutter/features/finishing/data/finishing_local_cost_posting.dart';

void main() {
  late AppDatabase db;
  late FinishingPendingEventRepository pending;
  late FinishingLocalCostPosting posting;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    pending = FinishingPendingEventRepository(db);
    posting = FinishingLocalCostPosting(db);
    await db.customStatement(
      "INSERT INTO finishing_projects(id,person_sync_id,name,start_date,created_at,updated_at) "
      "VALUES ('p1','person-1','Project','2026-11-09',1,1)",
    );
    await db.customStatement(
      "INSERT INTO finishing_trades(id,project_id,label) VALUES ('t1','p1','Painting')",
    );
    await db.customStatement(
      "INSERT INTO accounts(id,sync_id,name,type,opening_balance,color) "
      "VALUES (100,'acc-100','Cash','cash',1000,'#000000')",
    );
    await db.customStatement(
      "INSERT INTO categories(id,name,icon,color,type,is_default) "
      "VALUES (101,'Custody','wallet','#000000','trust',0)",
    );
    await db.customStatement(
      "INSERT INTO categories(id,name,icon,color,type,is_default) "
      "VALUES (102,'Finishing expense','wallet','#000000','expense',0)",
    );
    await pending.enqueueCost(
      eventId: 'cost-1', projectId: 'p1', tradeId: 't1',
      occurredAt: '2026-11-09', createdAt: 1,
      amountPiasters: 10000, custodyPiasters: 7000, personalPiasters: 3000,
      description: 'Paint', costType: 'materials',
    );
  });
  tearDown(() async => db.close());

  Future<void> post({int trustCategory = 101, int personalCategory = 102}) =>
      posting.post(
        eventId: 'cost-1', accountSyncId: 'acc-100',
        custodyCategoryId: trustCategory, personalCategoryId: personalCategory,
        date: DateTime(2026, 11, 9),
      );

  Future<int> count(String table) async {
    final row = await db.customSelect('SELECT count(*) AS n FROM $table').getSingle();
    return row.read<int>('n');
  }

  test('mixed cost creates two cash movements and marks posted', () async {
    await post();
    expect(await count('transactions'), 2);
    expect(await count('finishing_cash_legs'), 2);
    final movements = await db.customSelect(
      "SELECT type,amount FROM transactions WHERE sync_id LIKE 'finishing:%' ORDER BY type",
    ).get();
    expect(movements.map((m) => m.read<String>('type')).toSet(), {'expense', 'trustOut'});
    expect(movements.map((m) => m.read<double>('amount')).toSet(), {30.0, 70.0});
    final event = await db.customSelect(
      "SELECT status FROM finishing_events WHERE id = 'cost-1'",
    ).getSingle();
    expect(event.read<String>('status'), 'posted');
  });

  test('retry cannot create another expense or cash leg', () async {
    await post();
    await expectLater(post(), throwsStateError);
    expect(await count('transactions'), 2);
    expect(await count('finishing_cash_legs'), 2);
  });

  test('invalid category rolls back all writes and keeps event pending', () async {
    await expectLater(post(trustCategory: 102), throwsStateError);
    expect(await count('transactions'), 0);
    expect(await count('finishing_cash_legs'), 0);
    final event = await db.customSelect(
      "SELECT status FROM finishing_events WHERE id = 'cost-1'",
    ).getSingle();
    expect(event.read<String>('status'), 'pending');
  });

  test('closed project blocks posting without cash movement', () async {
    await db.customStatement(
      "UPDATE finishing_projects SET financial_status = 'closed' WHERE id = 'p1'",
    );
    await expectLater(post(), throwsStateError);
    expect(await count('transactions'), 0);
  });
}
