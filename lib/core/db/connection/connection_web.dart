import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Browser (PWA): SQLite compiled to WebAssembly, stored in the browser (OPFS or IndexedDB).
/// `web/sqlite3.wasm` and `web/drift_worker.js` are served next to the app.
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'masarefy',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}

/// The browser database is not encrypted with a keystore key, so there is nothing to recover.
Future<void> ensureDatabaseReadable() async {}
