import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../data/beneficiary_repository.dart';

final beneficiaryRepositoryProvider = Provider<BeneficiaryRepository>((ref) {
  return BeneficiaryRepository(ref.watch(databaseProvider));
});

final recentBeneficiariesProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(beneficiaryRepositoryProvider).listRecent();
});
