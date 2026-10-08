import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../data/account_repository.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) => AccountRepository(ref.watch(databaseProvider)));

final accountsProvider = StreamProvider<List<AccountWithBalance>>(
  (ref) => ref.watch(accountRepositoryProvider).watchAccounts(),
);

final accountProvider = StreamProvider.family<AccountWithBalance?, int>(
  (ref, id) => ref.watch(accountRepositoryProvider).watchAccount(id),
);

/// Sum of all active accounts' balances ("إجمالي الأموال").
final totalBalanceProvider = Provider<double>((ref) {
  final list = ref.watch(accountsProvider).value ?? const <AccountWithBalance>[];
  return list.fold<double>(0, (s, a) => s + a.balance);
});
