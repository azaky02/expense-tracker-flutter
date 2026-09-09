import 'package:drift/drift.dart';

import '../../../core/db/database.dart';

class BankRepository {
  BankRepository(this._db);
  final AppDatabase _db;

  Stream<List<Bank>> watchAll() {
    return (_db.select(_db.banks)..orderBy([(b) => OrderingTerm.asc(b.name)])).watch();
  }

  Future<int> createCustom(String name) {
    return _db.into(_db.banks).insert(
          BanksCompanion.insert(name: name, isCustom: const Value(true)),
        );
  }
}
