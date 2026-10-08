import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../data/ledger_repository.dart';

final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) => LedgerRepository(ref.watch(databaseProvider)));

final peopleWithBalancesProvider = StreamProvider<List<PersonWithBalance>>(
  (ref) => ref.watch(ledgerRepositoryProvider).watchPeopleWithBalances(),
);

final personProvider = StreamProvider.family<Person?, int>((ref, id) => ref.watch(ledgerRepositoryProvider).watchPerson(id));

final personEntriesProvider = StreamProvider.family<List<LedgerEntry>, int>(
  (ref, id) => ref.watch(ledgerRepositoryProvider).watchEntriesFor(id),
);

final statementProvider = StreamProvider.family<List<StatementLine>, int>(
  (ref, id) => ref.watch(ledgerRepositoryProvider).watchStatement(id),
);

final notificationsProvider = StreamProvider<List<AppNotification>>(
  (ref) => ref.watch(ledgerRepositoryProvider).watchNotifications(),
);

final unreadNotificationsProvider = StreamProvider<int>(
  (ref) => ref.watch(ledgerRepositoryProvider).watchUnreadCount(),
);

/// Totals across everyone: (they owe me, I owe them).
final outstandingTotalsProvider = Provider<(double, double)>((ref) {
  final list = ref.watch(peopleWithBalancesProvider).value ?? const <PersonWithBalance>[];
  var receivable = 0.0, payable = 0.0;
  for (final p in list) {
    receivable += p.balance.heOwesMe;
    payable += p.balance.iOweHim;
  }
  return (receivable, payable);
});

final pendingIncomingProvider = StreamProvider<int>(
  (ref) => ref.watch(ledgerRepositoryProvider).watchPendingIncomingCount(),
);
