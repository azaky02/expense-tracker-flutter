// Opens the app database: an encrypted SQLite file on Android/iOS, SQLite (WebAssembly) in the
// browser for the PWA.
export 'connection_native.dart' if (dart.library.js_interop) 'connection_web.dart';
