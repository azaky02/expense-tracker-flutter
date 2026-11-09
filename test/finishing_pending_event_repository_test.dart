import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/features/finishing/data/finishing_pending_event_repository.dart';

void main() {
  late AppDatabase db;
  late FinishingPendingEventRepository repo;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FinishingPendingEventRepository(db);
    await db.customStatement(
      "INSERT INTO finishing_projects(id, person_sync_id, name, start_date, created_at, updated_at) "
      "VALUES ('p1', 'person-1', 'Test', '2026-11-09', 1, 1)",
    );
  });
  tearDown(() async => db.close());

  Future<void> enqueue({String id = 'e1', String kind = 'client_advance'}) =>
      repo.enqueue(eventId: id, projectId: 'p1', kind: kind,
          occurredAt: '2026-11-09', createdAt: 1);

  Future<void> addTrade() => db.customStatement(
    "INSERT INTO finishing_trades(id,project_id,label) VALUES ('t1','p1','Paint')",
  );

  Future<void> cost({int custody = 7000, int personal = 3000, String trade = 't1'}) =>
      repo.enqueueCost(
        eventId: 'cost-1',
        projectId: 'p1',
        tradeId: trade,
        occurredAt: '2026-11-09',
        createdAt: 1,
        amountPiasters: 10000,
        custodyPiasters: custody,
        personalPiasters: personal,
        description: 'Paint supplies',
        costType: 'materials',
      );

  test('atomic cost staging creates exactly one cost and two allocations', () async {
    await addTrade();
    await cost();
    await cost();
    final events = await db.customSelect(
      "SELECT count(*) AS n FROM finishing_events WHERE id = 'cost-1'",
    ).getSingle();
    final split = await db.customSelect(
      "SELECT sum(amount_piasters) AS total FROM finishing_allocations WHERE event_id = 'cost-1'",
    ).getSingle();
    expect(events.read<int>('n'), 1);
    expect(split.read<int>('total'), 10000);
  });

  test('cost retry with different split is rejected', () async {
    await addTrade();
    await cost();
    await expectLater(cost(custody: 6000, personal: 4000), throwsStateError);
  });

  test('invalid trade rolls back entire cost event', () async {
    await expectLater(cost(), throwsStateError);
    final rows = await db.customSelect(
      "SELECT count(*) AS n FROM finishing_events WHERE id = 'cost-1'",
    ).getSingle();
    expect(rows.read<int>('n'), 0);
  });

  test('cost staging does not create real cash transaction', () async {
    await addTrade();
    await cost();
    final row = await db.customSelect('SELECT count(*) AS n FROM transactions').getSingle();
    expect(row.read<int>('n'), 0);
  });

  test('same pending event retried creates only one row', () async {
    await enqueue();
    await enqueue();
    final row = await db.customSelect(
      "SELECT count(*) AS n FROM finishing_events WHERE id = 'e1'",
    ).getSingle();
    expect(row.read<int>('n'), 1);
  });

  test('changed payload under same id is rejected', () async {
    await enqueue();
    await expectLater(enqueue(kind: 'cost'), throwsStateError);
  });

  test('closed projects reject new pending events', () async {
    await db.customStatement(
      "UPDATE finishing_projects SET financial_status = 'closed' WHERE id = 'p1'",
    );
    await expectLater(enqueue(), throwsStateError);
  });

  test('enqueue does not change existing transactions or ledger', () async {
    await enqueue();
    final transactions = await db.customSelect(
      'SELECT count(*) AS n FROM transactions',
    ).getSingle();
    final ledger = await db.customSelect(
      'SELECT count(*) AS n FROM ledger_entries',
    ).getSingle();
    expect(transactions.read<int>('n'), 0);
    expect(ledger.read<int>('n'), 0);
  });
}
