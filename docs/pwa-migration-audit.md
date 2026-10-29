# PWA migration — verified build blocker (2026-10-29)

Baseline: c605d97ad964fa04f2b48f6a3132025cc0a53bd4 (2026-10-16 01:20:29 Africa/Cairo).
Source: GitHub Actions web compatibility run #1, supplied log archive.

## Confirmed blocker
The web compiler reports `Dart library 'dart:ffi' is not available on this platform` followed by missing `Pointer`, `NativeFunction` and `DynamicLibrary` types. The current `lib/core/db/database.dart` imports `dart:io`, `drift/native.dart` and `sqlite3/sqlite3.dart`, and uses a native encrypted SQLite connection. That implementation cannot be imported into a browser build.

## Safe implementation sequence
1. Extract the native-only connection and unreadable-database recovery into a separate implementation.
2. Select the connection with Dart conditional imports, not runtime `kIsWeb` checks (which do not prevent compile-time imports).
3. Implement a browser-compatible Drift executor and test schema creation and migrations. Do not claim that IndexedDB or browser storage has the same encryption guarantees as sqlite3mc.
4. Audit other platform-specific imports, authentication, notifications, file handling, backups, and attachment APIs.
5. Run `flutter build web --release` in CI; then functional browser tests before any deployment.
6. Keep the original `master` branch untouched.

No financial data should be entered in an experimental web build until encryption, session storage, backups, and recovery have been reviewed.
