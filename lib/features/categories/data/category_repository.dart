import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';

class CategoryTreeNode {
  const CategoryTreeNode({required this.main, required this.children});
  final Category main;
  final List<Category> children;
}

class CategoryRepository {
  CategoryRepository(this._db);
  final AppDatabase _db;

  Stream<List<Category>> watchAll({CategoryType? type}) {
    final query = _db.select(_db.categories);
    if (type != null) {
      query.where((c) => c.type.equalsValue(type));
    }
    return query.watch();
  }

  /// Groups categories into main categories with their (at most one level of) children.
  Stream<List<CategoryTreeNode>> watchTree({CategoryType? type}) {
    return watchAll(type: type).map((all) {
      final mains = all.where((c) => c.parentCategoryId == null).toList();
      return mains.map((main) => CategoryTreeNode(main: main, children: all.where((c) => c.parentCategoryId == main.id).toList())).toList();
    });
  }

  Future<int> create({
    required String name,
    required String icon,
    required String color,
    required CategoryType type,
    int? parentCategoryId,
  }) {
    return _db
        .into(_db.categories)
        .insert(CategoriesCompanion.insert(name: name, icon: icon, color: color, type: type, parentCategoryId: Value(parentCategoryId)));
  }

  Future<void> update(int id, {required String name, required String icon, required String color}) {
    return (_db.update(
      _db.categories,
    )..where((c) => c.id.equals(id))).write(CategoriesCompanion(name: Value(name), icon: Value(icon), color: Value(color)));
  }

  /// Cascades to sub-categories via the FK's onDelete behavior isn't set at the drift level
  /// (drift references() don't cascade by default) — delete children first explicitly.
  /// Built-in categories other features rely on; they can be renamed but not deleted.
  static const protectedSyncIds = {
    'seed-cat-transfer',
    'seed-cat-trust',
    'seed-cat-installments',
    'seed-cat-association',
    'seed-cat-association-in',
    'seed-cat-car',
    'seed-cat-car-fuel',
    'seed-cat-car-oil',
    'seed-cat-10',
  };

  static bool isProtected(Category c) => protectedSyncIds.contains(c.syncId);

  Future<List<int>> _family(int id) async {
    final children = await (_db.select(_db.categories)..where((c) => c.parentCategoryId.equals(id))).get();
    return [id, for (final c in children) c.id];
  }

  Future<bool> hasProtected(int id) async {
    final ids = await _family(id);
    final rows = await (_db.select(_db.categories)..where((c) => c.id.isIn(ids))).get();
    return rows.any(isProtected);
  }

  /// Transactions filed under the category or its sub-categories.
  Future<int> usageCount(int id) async {
    final ids = await _family(id);
    final count = _db.transactions.id.count();
    final row =
        await (_db.selectOnly(_db.transactions)
              ..addColumns([count])
              ..where(_db.transactions.categoryId.isIn(ids)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Deletes the category, its sub-categories and their budgets; transactions move to [moveTo] first.
  Future<void> delete(int id, {int? moveTo}) async {
    await _db.transaction(() async {
      final ids = await _family(id);
      if (moveTo != null) {
        await (_db.update(_db.transactions)..where((t) => t.categoryId.isIn(ids))).write(TransactionsCompanion(categoryId: Value(moveTo)));
      }
      await (_db.delete(_db.categoryBudgets)..where((b) => b.categoryId.isIn(ids))).go();
      await (_db.delete(_db.categories)..where((c) => c.parentCategoryId.equals(id))).go();
      await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
    });
  }
}
