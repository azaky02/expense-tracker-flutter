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
      return mains
          .map(
            (main) => CategoryTreeNode(
              main: main,
              children: all.where((c) => c.parentCategoryId == main.id).toList(),
            ),
          )
          .toList();
    });
  }

  Future<int> create({
    required String name,
    required String icon,
    required String color,
    required CategoryType type,
    int? parentCategoryId,
  }) {
    return _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            name: name,
            icon: icon,
            color: color,
            type: type,
            parentCategoryId: Value(parentCategoryId),
          ),
        );
  }

  Future<void> update(int id, {required String name, required String icon, required String color}) {
    return (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(name: Value(name), icon: Value(icon), color: Value(color)),
    );
  }

  /// Cascades to sub-categories via the FK's onDelete behavior isn't set at the drift level
  /// (drift references() don't cascade by default) — delete children first explicitly.
  Future<void> delete(int id) async {
    await (_db.delete(_db.categories)..where((c) => c.parentCategoryId.equals(id))).go();
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }
}
