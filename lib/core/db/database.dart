import 'package:drift/drift.dart';

import '../sync/sync_schema.dart';
import 'database_connection_native.dart' if (dart.library.js_interop) 'database_connection_web.dart' as connection;
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
    Installments,
    InstallmentPayments,
    Cars,
    FuelTypes,
    CarExpenses,
    Associations,
    AssociationPayments,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(connection.openConnection());

  /// For tests: run against any executor (e.g. an in-memory database).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await customStatement('CREATE INDEX idx_transactions_date ON transactions(date);');
      await customStatement('CREATE INDEX idx_transactions_category ON transactions(category_id);');
      await customStatement('CREATE INDEX idx_transactions_card ON transactions(card_id);');
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
        await m.addColumn(ledgerEntries, ledgerEntries.paymentMethod);
        // The change trigger must now also watch the new account columns.
        await customStatement('DROP TRIGGER IF EXISTS sync_au_transactions');
        await createSyncObjects(this);
      }
      if (from < 5) {
        // v5: installments, cars and fuel prices (on-device only, not synced).
        await m.createTable(installments);
        await m.createTable(installmentPayments);
        await m.createTable(cars);
        await m.createTable(fuelTypes);
        await m.createTable(carExpenses);
      }
      if (from >= 5 && from < 6) {
        // v6: car maintenance reminders (a v5 database already has the cars table).
        await m.addColumn(cars, cars.oilIntervalKm);
        await m.addColumn(cars, cars.oilIntervalMonths);
        await m.addColumn(cars, cars.licenseExpiry);
        await m.addColumn(cars, cars.insuranceExpiry);
      }
      if (from >= 5 && from < 7) {
        // v7: installments can be loans (v5 databases already have the installments table).
        await m.addColumn(installments, installments.kind);
      }
      if (from < 7) {
        await m.createTable(associations);
        await m.createTable(associationPayments);
      }
      if (from >= 5 && from < 8) {
        // v8: tips on car expenses.
        await m.addColumn(carExpenses, carExpenses.tips);
      }
    },
  );
}

/// Set when a native database could not be decrypted during recovery.
const unreadableDbRecoveredKey = 'db.unreadableRecovered';

/// Checks and recovers native encrypted storage when possible.
/// Web storage has a separate lifecycle and does not perform native file recovery.
Future<void> ensureDatabaseReadable() => connection.ensureDatabaseReadable();
