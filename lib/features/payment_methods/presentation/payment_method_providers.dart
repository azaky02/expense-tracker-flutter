import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../data/bank_repository.dart';
import '../data/card_repository.dart';

final bankRepositoryProvider = Provider<BankRepository>((ref) {
  return BankRepository(ref.watch(databaseProvider));
});

final bankListProvider = StreamProvider((ref) => ref.watch(bankRepositoryProvider).watchAll());

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return CardRepository(ref.watch(databaseProvider));
});

final activeCardsProvider = StreamProvider((ref) => ref.watch(cardRepositoryProvider).watchActive());

final cardByIdProvider = FutureProvider.family((ref, int id) {
  return ref.watch(cardRepositoryProvider).getById(id);
});
