import 'package:drift/drift.dart';

/// Additive v9 storage for finishing projects.
///
/// These tables deliberately use raw SQL until the generated Drift schema and
/// server-authoritative posting protocol are introduced in a later task.
/// No existing account, transaction or shared-ledger row is modified here.
Future<void> createFinishingSchemaV9(DatabaseConnectionUser db) async {
  const statements = <String>[
    '''
CREATE TABLE IF NOT EXISTS finishing_projects (
  id TEXT NOT NULL PRIMARY KEY,
  person_sync_id TEXT NOT NULL,
  name TEXT NOT NULL CHECK(length(trim(name)) > 0),
  location TEXT,
  start_date TEXT NOT NULL,
  planned_end_date TEXT,
  budget_piasters INTEGER CHECK(budget_piasters IS NULL OR budget_piasters >= 0),
  work_status TEXT NOT NULL DEFAULT 'new'
    CHECK(work_status IN ('new','active','paused','completed')),
  financial_status TEXT NOT NULL DEFAULT 'open'
    CHECK(financial_status IN ('open','closed')),
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)''',
    '''
CREATE TABLE IF NOT EXISTS finishing_trades (
  id TEXT NOT NULL PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES finishing_projects(id) ON DELETE RESTRICT,
  label TEXT NOT NULL CHECK(length(trim(label)) > 0),
  sort_order INTEGER NOT NULL DEFAULT 0,
  UNIQUE(project_id, label)
)''',
    '''
CREATE TABLE IF NOT EXISTS finishing_events (
  id TEXT NOT NULL PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES finishing_projects(id) ON DELETE RESTRICT,
  kind TEXT NOT NULL CHECK(kind IN (
    'client_advance','personal_allocation','cost','reimburse_from_custody',
    'client_repay_personal','return_custody','reversal'
  )),
  occurred_at TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK(status IN ('pending','posted','reversed')),
  reverses_event_id TEXT UNIQUE REFERENCES finishing_events(id) ON DELETE RESTRICT,
  memo TEXT,
  created_at INTEGER NOT NULL
)''',
    '''
CREATE TABLE IF NOT EXISTS finishing_cost_details (
  event_id TEXT NOT NULL PRIMARY KEY REFERENCES finishing_events(id) ON DELETE RESTRICT,
  trade_id TEXT NOT NULL REFERENCES finishing_trades(id) ON DELETE RESTRICT,
  cost_type TEXT NOT NULL CHECK(cost_type IN ('materials','labor','other')),
  amount_piasters INTEGER NOT NULL CHECK(amount_piasters > 0),
  description TEXT NOT NULL CHECK(length(trim(description)) > 0),
  payee TEXT
)''',
    '''
CREATE TABLE IF NOT EXISTS finishing_allocations (
  id TEXT NOT NULL PRIMARY KEY,
  event_id TEXT NOT NULL REFERENCES finishing_events(id) ON DELETE RESTRICT,
  funding_source TEXT NOT NULL CHECK(funding_source IN ('client_custody','personal')),
  amount_piasters INTEGER NOT NULL CHECK(amount_piasters > 0),
  UNIQUE(event_id, funding_source)
)''',
    '''
CREATE TABLE IF NOT EXISTS finishing_cash_legs (
  id TEXT NOT NULL PRIMARY KEY,
  event_id TEXT NOT NULL REFERENCES finishing_events(id) ON DELETE RESTRICT,
  account_sync_id TEXT NOT NULL,
  direction TEXT NOT NULL CHECK(direction IN ('in','out')),
  amount_piasters INTEGER NOT NULL CHECK(amount_piasters > 0),
  existing_transaction_sync_id TEXT UNIQUE,
  UNIQUE(event_id, account_sync_id, direction)
)''',
    '''
CREATE TABLE IF NOT EXISTS finishing_audit (
  id TEXT NOT NULL PRIMARY KEY,
  event_id TEXT REFERENCES finishing_events(id) ON DELETE RESTRICT,
  project_id TEXT NOT NULL REFERENCES finishing_projects(id) ON DELETE RESTRICT,
  action TEXT NOT NULL,
  recorded_at INTEGER NOT NULL,
  details_json TEXT NOT NULL
)''',
    '''
CREATE TABLE IF NOT EXISTS finishing_attachments (
  id TEXT NOT NULL PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES finishing_projects(id) ON DELETE RESTRICT,
  event_id TEXT REFERENCES finishing_events(id) ON DELETE RESTRICT,
  local_uri TEXT,
  metadata_json TEXT NOT NULL DEFAULT '{}'
)''',
    'CREATE INDEX IF NOT EXISTS idx_finishing_projects_person ON finishing_projects(person_sync_id)',
    'CREATE INDEX IF NOT EXISTS idx_finishing_trades_project ON finishing_trades(project_id)',
    'CREATE INDEX IF NOT EXISTS idx_finishing_events_project_date ON finishing_events(project_id, occurred_at, id)',
    'CREATE INDEX IF NOT EXISTS idx_finishing_allocations_event ON finishing_allocations(event_id)',
    'CREATE INDEX IF NOT EXISTS idx_finishing_cash_legs_event ON finishing_cash_legs(event_id)',
    'CREATE INDEX IF NOT EXISTS idx_finishing_audit_project ON finishing_audit(project_id, recorded_at)',
    'CREATE INDEX IF NOT EXISTS idx_finishing_attachments_project ON finishing_attachments(project_id)',
  ];
  for (final sql in statements) {
    await db.customStatement(sql);
  }
}
