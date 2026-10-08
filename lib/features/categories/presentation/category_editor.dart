import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart' hide Card;
import '../../../core/db/tables.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';
import 'category_providers.dart';

const categoryPaletteChoices = [
  AppColors.teal600,
  AppColors.orange600,
  AppColors.navy600,
  AppColors.red500,
  AppColors.brown600,
  AppColors.grey400,
  AppColors.teal700,
  AppColors.orange700,
];

/// Add / edit dialog shared by the category management screen and the transaction form's picker.
/// Returns the id of the created or edited category, or null if the user cancelled.
Future<int?> showCategoryEditor(
  BuildContext context,
  WidgetRef ref, {
  required CategoryType type,
  int? parentCategoryId,
  Category? existing,
}) async {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final iconController = TextEditingController(text: existing?.icon ?? '📦');
  var selectedColor = existing != null ? colorFromHex(existing.color) : categoryPaletteChoices.first;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(
          (existing == null
                  ? (parentCategoryId == null ? 'categories.addCategory' : 'categories.addSubCategory')
                  : 'categories.editCategory')
              .tr(context: ctx),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(labelText: 'categories.name'.tr(context: ctx)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: iconController,
                decoration: InputDecoration(labelText: 'categories.icon'.tr(context: ctx)),
              ),
              const SizedBox(height: 12),
              Text('categories.color'.tr(context: ctx)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in categoryPaletteChoices)
                    GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selectedColor == color ? Border.all(color: Colors.black, width: 2) : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr(context: ctx)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('common.save'.tr(context: ctx)),
          ),
        ],
      ),
    ),
  );

  final name = nameController.text.trim();
  final icon = iconController.text.trim().isEmpty ? '📦' : iconController.text.trim();
  nameController.dispose();
  iconController.dispose();
  if (saved != true || name.isEmpty) return null;

  final repo = ref.read(categoryRepositoryProvider);
  if (existing == null) {
    return repo.create(
      name: name,
      icon: icon,
      color: colorToHex(selectedColor),
      type: type,
      parentCategoryId: parentCategoryId,
    );
  }
  await repo.update(existing.id, name: name, icon: icon, color: colorToHex(selectedColor));
  return existing.id;
}
