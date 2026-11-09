import 'package:drift/drift.dart';

import '../../../core/db/database.dart';

/// Local pending-event journal only. This does NOT post real-account transactions,
/// change custody balances, or confirm financial events on the server.
class FinishingPendingEventRepository {
  FinishingPendingEventRepository(this._db);

  final AppDatabase _db;

  /// Caller supplies a stable UUID, reused on retries.
  /// A duplicate with identical payload is idempotent; a changed payload is rejected.
  Future<void> enqueue({
    required String eventId,
    required String projectId,
    required String kind,
    required String occurredAt,
    required int createdAt,
    String? memo,
  }) async {
    if (eventId.trim().isEmpty || projectId.trim().isEmpty) {
      throw ArgumentError('eventId and projectId are required');
    }
    const supported = {
      'client_advance', 'personal_allocation', 'cost',
      'reimburse_from_custody', 'client_repay_personal', 'return_custody',
    };
    if (!supported.contains(kind)) throw ArgumentError.value(kind, 'kind');
    await _db.transaction(() async {
      final rows = await _db.customSelect(
        'SELECT project_id, kind, occurred_at, memo, created_at, status '
        'FROM finishing_events WHERE id = ?',
        variables: [Variable.withString(eventId)],
      ).get();
      if (rows.isNotEmpty) {
        final old = rows.single;
        if (old.read<String>('project_id') != projectId ||
            old.read<String>('kind') != kind ||
            old.read<String>('occurred_at') != occurredAt ||
            old.read<String?>('memo') != memo ||
            old.read<int>('created_at') != createdAt) {
          throw StateError('event id already used with different payload');
        }
        return;
      }
      final projects = await _db.customSelect(
        'SELECT financial_status FROM finishing_projects WHERE id = ?',
        variables: [Variable.withString(projectId)],
      ).get();
      if (projects.isEmpty) throw StateError('project not found');
      if (projects.single.read<String>('financial_status') != 'open') {
        throw StateError('project is financially closed');
      }
      await _db.customStatement(
        'INSERT INTO finishing_events '
        '(id, project_id, kind, occurred_at, status, memo, created_at) '
        "VALUES (?, ?, ?, ?, 'pending', ?, ?)",
        [
          eventId, projectId, kind, occurredAt, memo, createdAt,
        ],
      );
    });
  }
}
