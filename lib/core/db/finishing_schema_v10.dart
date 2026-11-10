import 'package:drift/drift.dart';

/// v10: a mixed cost may create two outgoing legs for the same account/event.
/// Keep each leg's primary key and transaction sync ID unique.
Future<void> migrateFinishingCashLegsV10(DatabaseConnectionUser db) async {
  await db.customStatement('''
CREATE TABLE finishing_cash_legs_v10 (
  id TEXT NOT NULL PRIMARY KEY,
  event_id TEXT NOT NULL REFERENCES finishing_events(id) ON DELETE RESTRICT,
  account_sync_id TEXT NOT NULL,
  direction TEXT NOT NULL CHECK(direction IN ('in','out')),
  amount_piasters INTEGER NOT NULL CHECK(amount_piasters > 0),
  existing_transaction_sync_id TEXT UNIQUE
)''');
  await db.customStatement('''
INSERT INTO finishing_cash_legs_v10
(id,event_id,account_sync_id,direction,amount_piasters,existing_transaction_sync_id)
SELECT id,event_id,account_sync_id,direction,amount_piasters,existing_transaction_sync_id
FROM finishing_cash_legs''');
  await db.customStatement('DROP TABLE finishing_cash_legs');
  await db.customStatement('ALTER TABLE finishing_cash_legs_v10 RENAME TO finishing_cash_legs');
  await db.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_finishing_cash_legs_event ON finishing_cash_legs(event_id)',
  );
}
