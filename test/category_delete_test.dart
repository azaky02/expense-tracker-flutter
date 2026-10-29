import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/core/db/seed.dart';
import 'package:expense_tracker_flutter/core/db/tables.dart';
import 'package:expense_tracker_flutter/features/accounts/data/account_repository.dart';
import 'package:expense_tracker_flutter/features/categories/data/category_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('delete category: protected ones refused, transactions moved first', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedIfNeeded(db);
    await ensureTrustCategory(db);
    await migrateToAccounts(db);
    final repo = CategoryRepository(db);
    final cash = (await AccountRepository(db).watchAccounts().first).first.account.id;
    final cats = {for (final c in await db.select(db.categories).get()) c.syncId: c.id};
    expect(await repo.hasProtected(cats['seed-cat-car']!), isTrue);
    expect(await repo.hasProtected(cats['seed-cat-0']!), isFalse);

    final main = await repo.create(name: 'تجربة', icon: '🧪', color: '#000000', type: CategoryType.expense);
    final sub = await repo.create(name: 'فرعي', icon: '🧪', color: '#000000', type: CategoryType.expense, parentCategoryId: main);
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        amount: 50, type: TransactionType.expense, categoryId: sub, paymentMethodType: PaymentMethodType.cash, date: DateTime(2026, 10, 1), accountId: Value(cash)));
    expect(await repo.usageCount(main), 1);

    await repo.delete(main, moveTo: cats['seed-cat-0']);
    final left = await db.select(db.categories).get();
    expect(left.any((c) => c.id == main || c.id == sub), isFalse);
    final t = await db.select(db.transactions).getSingle();
    expect(t.categoryId, cats['seed-cat-0']);
    await db.close();
  });
}
