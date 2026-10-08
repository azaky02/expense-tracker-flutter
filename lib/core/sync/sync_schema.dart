import '../db/database.dart';

/// One synced table: how it is named on the server, which local columns carry user data (the
/// ones whose change must mark the row dirty), and which column identifies it in a tombstone.
class SyncTable {
  const SyncTable(this.entity, this.table, this.dataColumns, {this.tombstoneExpr = 'OLD.sync_id'});
  final String entity;
  final String table;
  final List<String> dataColumns;
  /// SQL expression (evaluated in the AFTER DELETE trigger) for the server-side key of the row.
  final String tombstoneExpr;
}

/// Order matters: parents before children when applying remote changes.
const syncTables = <SyncTable>[
  SyncTable('banks', 'banks', ['name', 'logo_uri', 'is_custom']),
  SyncTable('categories', 'categories',
      ['parent_category_id', 'name', 'icon', 'color', 'type', 'is_default']),
  SyncTable('cards', 'cards', [
    'bank_id', 'card_type', 'card_category', 'nickname', 'last4_digits', 'due_date_day',
    'statement_date_day', 'credit_limit', 'color', 'is_active',
  ]),
  SyncTable('beneficiaries', 'beneficiaries', ['last_used_at'], tombstoneExpr: 'OLD.name'),
  SyncTable('transactions', 'transactions', [
    'amount', 'type', 'category_id', 'payment_method_type', 'card_id', 'date', 'note',
    'beneficiary_name',
  ]),
  SyncTable('people', 'people', ['name', 'phone', 'email', 'notes', 'linked_user_id']),
  SyncTable('categoryBudgets', 'category_budgets', ['category_id', 'monthly_limit', 'is_enabled'],
      tombstoneExpr: '(SELECT sync_id FROM categories WHERE id = OLD.category_id)'),
];

/// Meta key set (inside one DB transaction) while remote changes are being applied, so the
/// triggers below do not mistake them for local edits.
const syncApplyingKey = 'sync_applying';

const _notApplying =
    "COALESCE((SELECT value FROM meta WHERE key = '$syncApplyingKey'), '0') <> '1'";
const _now = "CAST(strftime('%s', 'now') AS INTEGER)";

/// Creates the unique sync_id indexes and the change-tracking triggers. Idempotent, so it runs
/// both on fresh installs and after the v1 → v2 upgrade.
Future<void> createSyncObjects(AppDatabase db) async {
  for (final t in syncTables) {
    await db.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_${t.table}_sync_id ON ${t.table}(sync_id)',
    );
    await db.customStatement('''
CREATE TRIGGER IF NOT EXISTS sync_ai_${t.table} AFTER INSERT ON ${t.table}
WHEN $_notApplying
BEGIN
  UPDATE ${t.table}
  SET sync_id = COALESCE(sync_id, lower(hex(randomblob(16)))), updated_at = $_now, dirty = 1
  WHERE rowid = NEW.rowid;
END''');
    await db.customStatement('''
CREATE TRIGGER IF NOT EXISTS sync_au_${t.table}
AFTER UPDATE OF ${t.dataColumns.join(', ')} ON ${t.table}
WHEN $_notApplying
BEGIN
  UPDATE ${t.table} SET updated_at = $_now, dirty = 1 WHERE rowid = NEW.rowid;
END''');
    await db.customStatement('''
CREATE TRIGGER IF NOT EXISTS sync_ad_${t.table} AFTER DELETE ON ${t.table}
WHEN $_notApplying AND (${t.tombstoneExpr}) IS NOT NULL
BEGIN
  INSERT INTO sync_tombstones(entity, key, deleted_at)
  VALUES ('${t.entity}', ${t.tombstoneExpr}, $_now);
END''');
  }
}

/// Stamps rows that existed before sync support: deterministic ids for the built-in defaults
/// (so two devices that each seeded their own copy end up with the same rows), random ids for
/// everything else.
Future<void> backfillSyncIds(AppDatabase db) async {
  await db.customStatement(
      "UPDATE banks SET sync_id = 'seed-bank-' || (id - 1) WHERE sync_id IS NULL AND is_custom = 0");
  await db.customStatement(
      "UPDATE categories SET sync_id = 'seed-cat-' || (id - 1) WHERE sync_id IS NULL AND is_default = 1");
  for (final t in syncTables) {
    if (t.table == 'beneficiaries') continue;
    await db.customStatement(
        'UPDATE ${t.table} SET sync_id = lower(hex(randomblob(16))) WHERE sync_id IS NULL');
  }
  for (final t in syncTables) {
    await db.customStatement('UPDATE ${t.table} SET updated_at = $_now WHERE updated_at = 0');
  }
}
