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
  /// Atomically stages a cost and its split; no account posting takes place.
  /// All ids must remain stable across retries.
  Future<void> enqueueCost({
    required String eventId,
    required String projectId,
    required String tradeId,
    required String occurredAt,
    required int createdAt,
    required int amountPiasters,
    required int custodyPiasters,
    required int personalPiasters,
    required String description,
    required String costType,
    String? payee,
  }) async {
    if (amountPiasters <= 0 ||
        custodyPiasters < 0 ||
        personalPiasters < 0 ||
        custodyPiasters + personalPiasters != amountPiasters) {
      throw ArgumentError('invalid cost funding split');
    }
    if (!{'materials', 'labor', 'other'}.contains(costType)) {
      throw ArgumentError.value(costType, 'costType');
    }
    if (description.trim().isEmpty) throw ArgumentError('description required');
    await _db.transaction(() async {
      final existing = await _db.customSelect(
        'SELECT id FROM finishing_events WHERE id = ?',
        variables: [Variable.withString(eventId)],
      ).get();
      if (existing.isNotEmpty) {
        final detail = await _db.customSelect(
          'SELECT trade_id, cost_type, amount_piasters, description, payee '
          'FROM finishing_cost_details WHERE event_id = ?',
          variables: [Variable.withString(eventId)],
        ).getSingleOrNull();
        final allocations = await _db.customSelect(
          'SELECT funding_source, amount_piasters FROM finishing_allocations '
          'WHERE event_id = ?',
          variables: [Variable.withString(eventId)],
        ).get();
        final split = {
          for (final row in allocations)
            row.read<String>('funding_source'): row.read<int>('amount_piasters'),
        };
        if (detail == null ||
            detail.read<String>('trade_id') != tradeId ||
            detail.read<String>('cost_type') != costType ||
            detail.read<int>('amount_piasters') != amountPiasters ||
            detail.read<String>('description') != description ||
            detail.read<String?>('payee') != payee ||
            (split['client_custody'] ?? 0) != custodyPiasters ||
            (split['personal'] ?? 0) != personalPiasters) {
          throw StateError('duplicate event id with different cost');
        }
        await enqueue(
          eventId: eventId,
          projectId: projectId,
          kind: 'cost',
          occurredAt: occurredAt,
          createdAt: createdAt,
        );
        return;
      }
      final trade = await _db.customSelect(
        'SELECT id FROM finishing_trades WHERE id = ? AND project_id = ?',
        variables: [Variable.withString(tradeId), Variable.withString(projectId)],
      ).getSingleOrNull();
      if (trade == null) throw StateError('trade does not belong to project');
      await enqueue(
        eventId: eventId,
        projectId: projectId,
        kind: 'cost',
        occurredAt: occurredAt,
        createdAt: createdAt,
      );
      await _db.customStatement(
        'INSERT INTO finishing_cost_details '
        '(event_id,trade_id,cost_type,amount_piasters,description,payee) '
        'VALUES (?,?,?,?,?,?)',
        [eventId, tradeId, costType, amountPiasters, description, payee],
      );
      if (custodyPiasters > 0) {
        await _db.customStatement(
          'INSERT INTO finishing_allocations '
          '(id,event_id,funding_source,amount_piasters) VALUES (?,?,?,?)',
          ['$eventId:custody', eventId, 'client_custody', custodyPiasters],
        );
      }
      if (personalPiasters > 0) {
        await _db.customStatement(
          'INSERT INTO finishing_allocations '
          '(id,event_id,funding_source,amount_piasters) VALUES (?,?,?,?)',
          ['$eventId:personal', eventId, 'personal', personalPiasters],
        );
      }
    });
  }

}
