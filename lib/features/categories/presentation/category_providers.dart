import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/db/tables.dart';
import '../data/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(databaseProvider));
});

final categoryTreeProvider =
    StreamProvider.family<List<CategoryTreeNode>, CategoryType?>((ref, type) {
  return ref.watch(categoryRepositoryProvider).watchTree(type: type);
});
