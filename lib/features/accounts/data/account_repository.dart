import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/utils/color_utils.dart';

class AccountWithBalance {
  const AccountWithBalance(this.account, this.balance);
  final Account account;
  /// opening balance + income − expenses − transfers out + transfers in.
  final double balance;
}

const cashAccountSyncId = 'seed-acc-cash';

/// SQL for an account's derived balance (kept in one place so every screen agrees).
const _balanceSql = '''
SELECT a.*, a.opening_balance + COALESCE((
  SELECT SUM(CASE
    WHEN t.type = 'income'   AND t.account_id = a.id    THEN t.amount
    WHEN t.type = 'expense'  AND t.account_id = a.id    THEN -t.amount
    WHEN t.type = 'transfer' AND t.account_id = a.id    THEN -t.amount
    WHEN t.type = 'transfer' AND t.to_account_id = a.id THEN t.amount
    ELSE 0 END)
  FROM transactions t WHERE t.account_id = a.id OR t.to_account_id = a.id), 0) AS balance
FROM accounts a''';

class AccountRepository {
  AccountRepository(this._db);
  final AppDatabase _db;

  Stream<List<AccountWithBalance>> watchAccounts({bool includeArchived = false}) {
    final where = includeArchived ? '' : ' WHERE a.is_active = 1';
    return _db
        .customSelect('$_balanceSql$where ORDER BY CASE a.type WHEN \'cash\' THEN 0 ELSE 1 END, a.id',
            readsFrom: {_db.accounts, _db.transactions})
        .watch()
        .map((rows) => [
              for (final r in rows)
                AccountWithBalance(_db.accounts.map(r.data), ((r.read<double>('balance')) * 100).roundToDouble() / 100),
            ]);
  }

  Stream<AccountWithBalance?> watchAccount(int id) {
    return _db
        .customSelect('$_balanceSql WHERE a.id = ?', variables: [Variable.withInt(id)], readsFrom: {_db.accounts, _db.transactions})
        .watchSingleOrNull()
        .map((r) => r == null ? null : AccountWithBalance(_db.accounts.map(r.data), r.read<double>('balance')));
  }

  Future<Account?> byId(int id) => (_db.select(_db.accounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<int> create({required String name, required AccountType type, double openingBalance = 0, String? color, int? cardId}) {
    return _db.into(_db.accounts).insert(AccountsCompanion.insert(
          name: name.trim(),
          type: type,
          openingBalance: Value(openingBalance),
          color: color ?? colorToHex(DS.palette[type.index % DS.palette.length]),
          cardId: Value(cardId),
        ));
  }

  Future<void> update(int id, {required String name, required double openingBalance, String? color}) {
    return (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(AccountsCompanion(
          name: Value(name.trim()),
          openingBalance: Value(openingBalance),
          color: color == null ? const Value.absent() : Value(color),
        ));
  }

  /// Accounts are archived, never deleted: their transactions keep pointing at them.
  Future<void> setActive(int id, bool active) =>
      (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(AccountsCompanion(isActive: Value(active)));
}

/// v1.2 → phase 2: a Cash account, one account per card, and every existing cash/card transaction
/// moved onto its account. Deterministic sync ids so devices migrating the same data converge.
Future<void> migrateToAccounts(AppDatabase db) async {
  const flag = 'accounts-v1';
  if (await (db.select(db.meta)..where((m) => m.key.equals(flag))).getSingleOrNull() != null) return;
  await db.transaction(() async {
    var cash = await (db.select(db.accounts)..where((a) => a.syncId.equals(cashAccountSyncId))).getSingleOrNull();
    if (cash == null) {
      await db.into(db.accounts).insert(AccountsCompanion.insert(
            name: 'كاش',
            type: AccountType.cash,
            color: colorToHex(DS.success),
            syncId: const Value(cashAccountSyncId),
          ));
      // Oldest possible version: a rename on another device always wins.
      await db.customStatement("UPDATE accounts SET updated_at = 1 WHERE sync_id = '$cashAccountSyncId'");
      cash = await (db.select(db.accounts)..where((a) => a.syncId.equals(cashAccountSyncId))).getSingle();
    }
    for (final card in await db.select(db.cards).get()) {
      await ensureCardAccount(db, card);
    }
    await db.customUpdate(
      "UPDATE transactions SET account_id = ? WHERE account_id IS NULL AND payment_method_type = 'cash' AND type IN ('expense','income')",
      variables: [Variable.withInt(cash.id)],
      updates: {db.transactions},
    );
    await db.customUpdate(
      'UPDATE transactions SET account_id = (SELECT a.id FROM accounts a WHERE a.card_id = transactions.card_id) '
      'WHERE account_id IS NULL AND card_id IS NOT NULL',
      updates: {db.transactions},
    );
    await db.into(db.meta).insert(MetaCompanion.insert(key: flag, value: 'true'));
  });
}

/// The account that stands for [card] (created on first use).
Future<int> ensureCardAccount(AppDatabase db, Card card) async {
  final existing = await (db.select(db.accounts)..where((a) => a.cardId.equals(card.id))).getSingleOrNull();
  if (existing != null) return existing.id;
  final syncId = card.syncId == null ? null : 'acc-${card.syncId}';
  if (syncId != null) {
    final bySync = await (db.select(db.accounts)..where((a) => a.syncId.equals(syncId))).getSingleOrNull();
    if (bySync != null) return bySync.id;
  }
  return db.into(db.accounts).insert(AccountsCompanion.insert(
        name: card.nickname,
        type: card.cardCategory == CardCategory.credit ? AccountType.creditCard : AccountType.debitCard,
        color: card.color,
        cardId: Value(card.id),
        isActive: Value(card.isActive),
        syncId: Value(syncId),
      ));
}
