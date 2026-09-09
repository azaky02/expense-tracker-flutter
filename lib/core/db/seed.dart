import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show Color;

import '../theme/app_colors.dart';
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

String _colorToHex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

Future<void> seedIfNeeded(AppDatabase db) async {
  final existing = await (db.select(db.meta)..where((m) => m.key.equals(_seedFlagKey)))
      .getSingleOrNull();
  if (existing != null) return;

  await db.batch((batch) {
    batch.insertAll(
      db.banks,
      _defaultBanks.map((name) => BanksCompanion.insert(name: name)),
    );
  });

  for (final category in _defaultCategories) {
    final parentId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: category.name,
            icon: category.icon,
            color: _colorToHex(category.color),
            type: category.type,
            isDefault: const Value(true),
          ),
        );

    if (category.children.isNotEmpty) {
      await db.batch((batch) {
        batch.insertAll(
          db.categories,
          category.children.map(
            (child) => CategoriesCompanion.insert(
              parentCategoryId: Value(parentId),
              name: child.$1,
              icon: child.$2,
              color: _colorToHex(category.color),
              type: category.type,
              isDefault: const Value(true),
            ),
          ),
        );
      });
    }
  }

  await db.into(db.meta).insert(MetaCompanion.insert(key: _seedFlagKey, value: 'true'));
}
