import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../security/secure_storage.dart';
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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

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
