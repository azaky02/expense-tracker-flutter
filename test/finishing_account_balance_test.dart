import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_flutter/core/db/database.dart';
import 'package:expense_tracker_flutter/features/accounts/data/account_repository.dart';

void main() {
  test('trust receipts and payouts change real cash balance but not income/expense types', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO accounts(id,name,type,opening_balance,color) VALUES (100,'Cash','cash',100,'#000000')",
    );
    await db.customStatement(
      "INSERT INTO categories(id,name,icon,color,type,is_default) "
      "VALUES (100,'Custody','wallet','#000000','trust',0)",
    );
    final accounts = AccountRepository(db);
    final before = await accounts.watchAccount(100).first;
    expect(before!.balance, 100);
    await db.customUpdate(
      "INSERT INTO transactions(amount,type,category_id,payment_method_type,date,account_id) "
      "VALUES (500,'trustIn',100,'cash',1,100)",
      updates: {db.transactions},
    );
    final afterReceipt = await accounts.watchAccount(100).first;
    expect(afterReceipt!.balance, 600);
    await db.customUpdate(
      "INSERT INTO transactions(amount,type,category_id,payment_method_type,date,account_id) "
      "VALUES (175,'trustOut',100,'cash',1,100)",
      updates: {db.transactions},
    );
    final afterPayout = await accounts.watchAccount(100).first;
    expect(afterPayout!.balance, 425);
    final income = await db.customSelect(
      "SELECT count(*) AS n FROM transactions WHERE type = 'income' OR type = 'expense'",
    ).getSingle();
    expect(income.read<int>('n'), 0);
  });
}
