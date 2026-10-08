import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show Color;

import '../theme/app_colors.dart';
import '../utils/color_utils.dart';
import 'database.dart';
import 'tables.dart';

const _seedFlagKey = 'seed-completed-v1';

const _defaultBanks = [
  'CIB',
  'بنك مصر',
  'البنك الأهلي المصري',
  'QNB الأهلي',
  'بنك الإسكندرية',
  'HSBC',
  'ADIB',
  'بنك أبوظبي الأول',
  'بنك الرياض',
  'الراجحي',
  'بنك الكويت الوطني',
  'بنك مسقط',
];

class _CategorySeed {
  const _CategorySeed(this.name, this.icon, this.color, this.type, {this.children = const []});
  final String name;
  final String icon;
  final Color color;
  final CategoryType type;
  final List<(String name, String icon)> children;
}

final _defaultCategories = [
  _CategorySeed('أكل و شرب', '🍔', AppColors.teal600, CategoryType.expense),
  _CategorySeed(
    'مواصلات',
    '🚗',
    AppColors.orange600,
    CategoryType.expense,
    children: const [('بنزين', '⛽'), ('مواصلات عامة', '🚌'), ('صيانة عربية', '🔧')],
  ),
  _CategorySeed('فواتير', '🧾', AppColors.grey400, CategoryType.expense),
  _CategorySeed('ترفيه', '🎬', AppColors.navy600, CategoryType.expense),
  _CategorySeed('صحة', '💊', AppColors.red500, CategoryType.expense),
  _CategorySeed('أخرى', '📦', AppColors.grey300, CategoryType.expense),
  _CategorySeed(
    'دخل',
    '💰',
    AppColors.teal700,
    CategoryType.income,
    children: const [('راتب', '🏦'), ('دخل إضافي', '➕')],
  ),
];

Future<void> seedIfNeeded(AppDatabase db) async {
  final existing = await (db.select(db.meta)..where((m) => m.key.equals(_seedFlagKey)))
      .getSingleOrNull();
  if (existing != null) return;

  await db.batch((batch) {
    // Fixed sync ids: every device that seeds itself ends up with the *same* default rows,
    // so syncing two devices does not duplicate banks/categories.
    batch.insertAll(
      db.banks,
      [
        for (var i = 0; i < _defaultBanks.length; i++)
          BanksCompanion.insert(name: _defaultBanks[i], syncId: Value('seed-bank-$i')),
      ],
    );
  });

  var categorySeq = 0; // matches the row id order, see backfillSyncIds()
  for (final category in _defaultCategories) {
    final parentId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: category.name,
            icon: category.icon,
            color: colorToHex(category.color),
            type: category.type,
            isDefault: const Value(true),
            syncId: Value('seed-cat-${categorySeq++}'),
          ),
        );

    if (category.children.isNotEmpty) {
      await db.batch((batch) {
        batch.insertAll(
          db.categories,
          category.children.map(
            (child) => CategoriesCompanion.insert(
              syncId: Value('seed-cat-${categorySeq++}'),
              parentCategoryId: Value(parentId),
              name: child.$1,
              icon: child.$2,
              color: colorToHex(category.color),
              type: category.type,
              isDefault: const Value(true),
            ),
          ),
        );
      });
    }
  }

  // Defaults count as "oldest possible" versions: they still sync (so the server knows them), but
  // a rename made on another device always wins over a freshly seeded copy.
  await db.customStatement("UPDATE banks SET updated_at = 1 WHERE sync_id LIKE 'seed-%'");
  await db.customStatement("UPDATE categories SET updated_at = 1 WHERE sync_id LIKE 'seed-%'");

  await db.into(db.meta).insert(MetaCompanion.insert(key: _seedFlagKey, value: 'true'));
}


/// The single system category amanat transactions are filed under. Idempotent; runs on every start
/// so databases created before amanat existed get it too. Fixed sync id: it merges across devices.
Future<void> ensureTrustCategory(AppDatabase db) async {
  final existing = await (db.select(db.categories)..where((c) => c.syncId.equals('seed-cat-trust')))
      .getSingleOrNull();
  if (existing != null) return;
  await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: 'أمانات',
          icon: '🤝',
          color: colorToHex(AppColors.teal700),
          type: CategoryType.trust,
          isDefault: const Value(true),
          syncId: const Value('seed-cat-trust'),
        ),
      );
  await db.customStatement("UPDATE categories SET updated_at = 1 WHERE sync_id = 'seed-cat-trust'");
}
