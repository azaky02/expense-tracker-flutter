import 'package:drift/drift.dart';

import '../../../core/db/database.dart';

class BeneficiaryRepository {
  BeneficiaryRepository(this._db);
  final AppDatabase _db;

  /// Every known person/beneficiary, most recently used first (feeds the picker).
  Stream<List<String>> watchAll() {
    final query = _db.select(_db.beneficiaries)..orderBy([(b) => OrderingTerm.desc(b.lastUsedAt)]);
    return query.watch().map((rows) => rows.map((b) => b.name).toList());
  }

  Future<List<String>> listRecent({int limit = 10}) async {
    final query = _db.select(_db.beneficiaries)
      ..orderBy([(b) => OrderingTerm.desc(b.lastUsedAt)])
      ..limit(limit);
    final rows = await query.get();
    return rows.map((b) => b.name).toList();
  }
}
