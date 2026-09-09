import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'seed.dart';

/// The single AppDatabase instance for the app's lifetime.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Resolves once the DB is open and seed data has been inserted (first run only).
/// bootstrap.dart awaits this before showing anything beyond a splash placeholder.
final databaseReadyProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(databaseProvider);
  await seedIfNeeded(db);
});
