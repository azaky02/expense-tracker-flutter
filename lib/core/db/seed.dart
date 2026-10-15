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
  _CategorySeed('دخل', '💰', AppColors.teal700, CategoryType.income, children: const [('راتب', '🏦'), ('دخل إضافي', '➕')]),
];

Future<void> seedIfNeeded(AppDatabase db) async {
  final existing = await (db.select(db.meta)..where((m) => m.key.equals(_seedFlagKey))).getSingleOrNull();
  if (existing != null) return;

  await db.batch((batch) {
    // Fixed sync ids: every device that seeds itself ends up with the *same* default rows,
    // so syncing two devices does not duplicate banks/categories.
    batch.insertAll(db.banks, [
      for (var i = 0; i < _defaultBanks.length; i++) BanksCompanion.insert(name: _defaultBanks[i], syncId: Value('seed-bank-$i')),
    ]);
  });

  var categorySeq = 0; // matches the row id order, see backfillSyncIds()
  for (final category in _defaultCategories) {
    final parentId = await db
        .into(db.categories)
        .insert(
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
  await _ensureTransferCategory(db);
  await _ensureCarAndInstallmentData(db);
  final existing = await (db.select(db.categories)..where((c) => c.syncId.equals('seed-cat-trust'))).getSingleOrNull();
  if (existing != null) return;
  await db
      .into(db.categories)
      .insert(
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

/// System category every transfer between the user's own accounts is filed under.
Future<void> _ensureTransferCategory(AppDatabase db) async {
  final existing = await (db.select(db.categories)..where((c) => c.syncId.equals('seed-cat-transfer'))).getSingleOrNull();
  if (existing != null) return;
  await db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          name: 'تحويل',
          icon: '🔁',
          color: colorToHex(AppColors.navy600),
          type: CategoryType.transfer,
          isDefault: const Value(true),
          syncId: const Value('seed-cat-transfer'),
        ),
      );
  await db.customStatement("UPDATE categories SET updated_at = 1 WHERE sync_id = 'seed-cat-transfer'");
}

/// v5 master data: the car category tree, the installments category and fuel prices.
Future<void> _ensureCarAndInstallmentData(AppDatabase db) async {
  Future<void> ensureIncome(String syncId, String name, String icon) async {
    final existing = await (db.select(db.categories)..where((c) => c.syncId.equals(syncId))).getSingleOrNull();
    if (existing != null) return;
    // Under the built-in "دخل" main category.
    final parent = await (db.select(db.categories)..where((c) => c.syncId.equals('seed-cat-9'))).getSingleOrNull();
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name,
            icon: icon,
            color: colorToHex(AppColors.teal700),
            type: CategoryType.income,
            parentCategoryId: Value(parent?.id),
            isDefault: const Value(true),
            syncId: Value(syncId),
          ),
        );
    await db.customStatement("UPDATE categories SET updated_at = 1 WHERE sync_id = '$syncId'");
  }

  Future<int> ensure(String syncId, String name, String icon, Color color, {int? parent}) async {
    final existing = await (db.select(db.categories)..where((c) => c.syncId.equals(syncId))).getSingleOrNull();
    if (existing != null) return existing.id;
    final id = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name,
            icon: icon,
            color: colorToHex(color),
            type: CategoryType.expense,
            parentCategoryId: Value(parent),
            isDefault: const Value(true),
            syncId: Value(syncId),
          ),
        );
    await db.customStatement("UPDATE categories SET updated_at = 1 WHERE sync_id = '$syncId'");
    return id;
  }

  final car = await ensure('seed-cat-car', 'السيارة', '🚘', AppColors.navy600);
  const subs = [
    ('fuel', 'بنزين', '⛽'),
    ('service', 'صيانة', '🔧'),
    ('oil', 'تغيير زيت', '🛢️'),
    ('wash', 'غسيل', '🧽'),
    ('tires', 'إطارات', '🛞'),
    ('license', 'ترخيص', '📄'),
    ('insurance', 'تأمين', '🛡️'),
    ('parking', 'ركن', '🅿️'),
  ];
  for (final (key, name, icon) in subs) {
    await ensure('seed-cat-car-$key', name, icon, AppColors.navy600, parent: car);
  }
  await ensure('seed-cat-installments', 'أقساط', '📅', AppColors.teal700);
  await ensure('seed-cat-association', 'جمعية', '🤝', AppColors.teal700);
  await ensureIncome('seed-cat-association-in', 'قبض جمعية', '🪙');

  if (await db.select(db.fuelTypes).get().then((r) => r.isEmpty)) {
    for (final (name, price) in const [('بنزين 80', 17.75), ('بنزين 92', 19.25), ('بنزين 95', 21.0), ('سولار', 17.5)]) {
      await db.into(db.fuelTypes).insert(FuelTypesCompanion.insert(name: name, pricePerLiter: price));
    }
  }
}

/// Category ids of the seeded car tree / installments category.
Future<int?> seededCategoryId(AppDatabase db, String syncId) async =>
    (await (db.select(db.categories)..where((c) => c.syncId.equals(syncId))).getSingleOrNull())?.id;
