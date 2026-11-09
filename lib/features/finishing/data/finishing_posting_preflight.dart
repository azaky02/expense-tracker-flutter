import 'package:drift/drift.dart';

import '../../../core/db/database.dart';

/// Preflight gate for future server-authoritative financial posting.
/// Does not mutate transactions, balances, or event status.
class FinishingPostingPreflight {
  const FinishingPostingPreflight(this.db);
  final AppDatabase db;

  Future<void> validateCost({
    required String eventId,
    required String accountSyncId,
  }) async {
    if (eventId.isEmpty || accountSyncId.isEmpty) {
      throw ArgumentError('event and account are required');
    }
    final events = await db.customSelect(
      'SELECT e.status, e.kind, p.financial_status FROM finishing_events e '
      'JOIN finishing_projects p ON p.id = e.project_id WHERE e.id = ?',
      variables: [Variable.withString(eventId)],
    ).get();
    if (events.length != 1) throw StateError('event not found');
    final event = events.single;
    if (event.read<String>('status') != 'pending' ||
        event.read<String>('kind') != 'cost' ||
        event.read<String>('financial_status') != 'open') {
      throw StateError('event not eligible for posting');
    }
    final cost = await db.customSelect(
      'SELECT amount_piasters FROM finishing_cost_details WHERE event_id = ?',
      variables: [Variable.withString(eventId)],
    ).getSingleOrNull();
    if (cost == null) throw StateError('missing cost details');
    final allocation = await db.customSelect(
      'SELECT COALESCE(SUM(amount_piasters), 0) AS total '
      'FROM finishing_allocations WHERE event_id = ?',
      variables: [Variable.withString(eventId)],
    ).getSingle();
    if (allocation.read<int>('total') != cost.read<int>('amount_piasters')) {
      throw StateError('funding allocation does not equal cost');
    }
    final accounts = await db.customSelect(
      'SELECT id FROM accounts WHERE sync_id = ? AND is_active = 1',
      variables: [Variable.withString(accountSyncId)],
    ).get();
    if (accounts.length != 1) throw StateError('active account not found');
    final existingLeg = await db.customSelect(
      'SELECT id FROM finishing_cash_legs WHERE event_id = ?',
      variables: [Variable.withString(eventId)],
    ).get();
    if (existingLeg.isNotEmpty) throw StateError('event already has cash legs');
    final existingTx = await db.customSelect(
      'SELECT id FROM transactions WHERE sync_id = ?',
      variables: [Variable.withString('finishing:$eventId:cash')],
    ).get();
    if (existingTx.isNotEmpty) throw StateError('event already has a cash transaction');
  }
}
