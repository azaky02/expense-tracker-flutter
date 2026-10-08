import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../security/secure_storage.dart';
import '../sync/sync_schema.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Banks,
    Categories,
    Cards,
    Beneficiaries,
    Transactions,
    CategoryBudgets,
    NotificationPreferences,
    ScheduledNotifications,
    Meta,
    SyncTombstones,
    People,
    LedgerEntries,
    LedgerOutbox,
    AppNotifications,
    Accounts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For tests: run against any executor (e.g. an in-memory database).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX idx_transactions_date ON transactions(date);',
          );
          await customStatement(
            'CREATE INDEX idx_transactions_category ON transactions(category_id);',
          );
          await customStatement(
            'CREATE INDEX idx_transactions_card ON transactions(card_id);',
          );
          await createSyncObjects(this);
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            // v2: sync support (see core/sync/sync_schema.dart).
            await m.addColumn(banks, banks.syncId);
            await m.addColumn(banks, banks.updatedAt);
            await m.addColumn(banks, banks.dirty);
            await m.addColumn(categories, categories.syncId);
            await m.addColumn(categories, categories.updatedAt);
            await m.addColumn(categories, categories.dirty);
            await m.addColumn(cards, cards.syncId);
            await m.addColumn(cards, cards.updatedAt);
            await m.addColumn(cards, cards.dirty);
            await m.addColumn(beneficiaries, beneficiaries.syncId);
            await m.addColumn(beneficiaries, beneficiaries.updatedAt);
            await m.addColumn(beneficiaries, beneficiaries.dirty);
            await m.addColumn(transactions, transactions.syncId);
            await m.addColumn(transactions, transactions.updatedAt);
            await m.addColumn(transactions, transactions.dirty);
            await m.addColumn(categoryBudgets, categoryBudgets.syncId);
            await m.addColumn(categoryBudgets, categoryBudgets.updatedAt);
            await m.addColumn(categoryBudgets, categoryBudgets.dirty);
            await m.createTable(syncTombstones);
            await backfillSyncIds(this);
            await createSyncObjects(this);
          }
          if (from < 3) {
            // v3: People + Shared Ledger replica (V2 design). Existing amanat rows are moved into
            // the ledger after opening, see migrateAmanatToLedger().
            await m.createTable(people);
            await m.createTable(ledgerEntries);
            await m.createTable(ledgerOutbox);
            await m.createTable(appNotifications);
            await createSyncObjects(this);
          }
          if (from < 4) {
            // v4: accounts + transfers. Existing cash/card data is moved onto accounts after
            // opening, see migrateToAccounts().
            await m.createTable(accounts);
            await m.addColumn(transactions, transactions.accountId);
            await m.addColumn(transactions, transactions.toAccountId);
            // The change trigger must now also watch the new account columns.
            await customStatement('DROP TRIGGER IF EXISTS sync_au_transactions');
            await createSyncObjects(this);
          }
        },
      );
}

/// Opens the encrypted database on a background isolate.
///
/// sqlite3_flutter_libs / sqlcipher_flutter_libs are both EOL — encryption is configured via
/// the `hooks.user_defines.sqlite3.source: sqlite3mc` key in pubspec.yaml, which builds the
/// SQLite3MultipleCiphers native library instead of the old separate plugin packages.
/// SQLite3MultipleCiphers implements the standard SQLite C API, so NativeDatabase needs no
/// code changes beyond running `PRAGMA key` in the `setup` callback below.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // getApplicationSupportDirectory (not ApplicationDocuments) — excluded from iCloud backup
    // on iOS, since attachment photos referenced from this DB may contain financial receipts.
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'expense_tracker.sqlite'));
    final key = await SecureStorageService.instance.getOrCreateDbEncryptionKey();

    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        rawDb.execute("PRAGMA key = '$key';");
      },
    );
  });
}
