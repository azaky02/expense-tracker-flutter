import 'package:drift/drift.dart';
import 'package:drift/web.dart';

/// Browser-only experimental database.
///
/// WebDatabase requires sql.js assets at runtime. This executor does NOT
/// provide sqlite3mc encryption. Do not enter real financial data until
/// web encryption and recovery are designed and validated.
QueryExecutor openConnection() => WebDatabase('masarefy_pwa_experimental');

/// Native file recovery is not applicable in browsers.
Future<void> ensureDatabaseReadable() async {}
