import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../transactions/data/transaction_repository.dart';
import 'finishing_posting_preflight.dart';

/// LOCAL-ONLY atomic cost posting. Do not enable for multi-device use until
/// server-side authoritative idempotency and reconciliation are implemented.
class FinishingLocalCostPosting {
  FinishingLocalCostPosting(this.db);
  final AppDatabase db;

  /// [custodyCategoryId] must be a trust category and [personalCategoryId]
  /// must be an expense category. One account is debited for both shares.
  Future<void> post({
    required String eventId,
    required String accountSyncId,
    required int custodyCategoryId,
    required int personalCategoryId,
    required DateTime date,
  }) async {
    await db.transaction(() async {
      await FinishingPostingPreflight(db).validateCost(
        eventId: eventId,
        accountSyncId: accountSyncId,
      );
      final account = await db.customSelect(
        'SELECT id FROM accounts WHERE sync_id = ? AND is_active = 1',
        variables: [Variable.withString(accountSyncId)],
      ).getSingle();
      final accountId = account.read<int>('id');
      final categories = await db.customSelect(
        'SELECT id, type FROM categories WHERE id IN (?, ?)',
        variables: [Variable.withInt(custodyCategoryId), Variable.withInt(personalCategoryId)],
      ).get();
      final categoryTypes = {
        for (final c in categories) c.read<int>('id'): c.read<String>('type'),
      };
      if (categoryTypes[custodyCategoryId] != 'trust' ||
          categoryTypes[personalCategoryId] != 'expense') {
        throw StateError('posting requires trust and expense categories');
      }
      final allocations = await db.customSelect(
        'SELECT funding_source, amount_piasters FROM finishing_allocations WHERE event_id = ?',
        variables: [Variable.withString(eventId)],
      ).get();
      final shares = {
        for (final a in allocations)
          a.read<String>('funding_source'): a.read<int>('amount_piasters'),
      };
      final custody = shares['client_custody'] ?? 0;
      final personal = shares['personal'] ?? 0;
      if (custody + personal <= 0) throw StateError('empty cost');
      final transactions = TransactionRepository(db);
      for (final entry in [
        (share: custody, type: TransactionType.trustOut, category: custodyCategoryId, suffix: 'custody'),
        (share: personal, type: TransactionType.expense, category: personalCategoryId, suffix: 'personal'),
      ]) {
        if (entry.share == 0) continue;
        final syncId = 'finishing:$eventId:${entry.suffix}';
        await transactions.create(TransactionInput(
          amount: entry.share / 100,
          type: entry.type,
          categoryId: entry.category,
          paymentMethodType: PaymentMethodType.cash,
          date: date,
          accountId: accountId,
          idempotencyKey: syncId,
          note: 'Finishing project cost $eventId',
        ));
        await db.customStatement(
          'INSERT INTO finishing_cash_legs '
          '(id,event_id,account_sync_id,direction,amount_piasters,existing_transaction_sync_id) '
          "VALUES (?,?,?,'out',?,?)",
          ['$eventId:${entry.suffix}', eventId, accountSyncId, entry.share, syncId],
        );
      }
      await db.customStatement(
        "UPDATE finishing_events SET status = 'posted' WHERE id = ? AND status = 'pending'",
        [eventId],
      );
    });
  }
}
