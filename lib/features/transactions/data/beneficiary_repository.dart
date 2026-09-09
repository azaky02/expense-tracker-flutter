import 'package:drift/drift.dart';

import '../../../core/db/database.dart';

class BeneficiaryRepository {
  BeneficiaryRepository(this._db);
  final AppDatabase _db;

  Future<List<String>> listRecent({int limit = 10}) async {
    final query = _db.select(_db.beneficiaries)
      ..orderBy([(b) => OrderingTerm.desc(b.lastUsedAt)])
      ..limit(limit);
    final rows = await query.get();
    return rows.map((b) => b.name).toList();
  }
}
