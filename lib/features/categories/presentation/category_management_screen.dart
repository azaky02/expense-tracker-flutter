import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart' hide Card;
import '../../../core/db/tables.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';
import 'category_providers.dart';

const _paletteChoices = [
  AppColors.teal600,
  AppColors.orange600,
  AppColors.navy600,
  AppColors.red500,
  AppColors.brown600,
  AppColors.grey400,
  AppColors.teal700,
  AppColors.orange700,
];

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends ConsumerState<CategoryManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  CategoryType get _currentType =>
      _tabController.index == 0 ? CategoryType.expense : CategoryType.income;

  Future<void> _openEditor({
    required CategoryType type,
    int? parentCategoryId,
    Category? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final iconController = TextEditingController(text: existing?.icon ?? '📦');
    var selectedColor = existing != null ? colorFromHex(existing.color) : _paletteChoices.first;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'categories.addCategory'.tr() : 'categories.editCategory'.tr()),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: 'categories.name'.tr()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: iconController,
                      decoration: InputDecoration(labelText: 'categories.icon'.tr()),
                    ),
                    const SizedBox(height: 12),
                    Text('categories.color'.tr()),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final color in _paletteChoices)
                          GestureDetector(
                            onTap: () => setDialogState(() => selectedColor = color),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: selectedColor == color
                                    ? Border.all(color: Colors.black, width: 2)
                                    : null,
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
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('common.cancel'.tr()),
                ),
                FilledButton(
                  onPressed: nameController.text.trim().isEmpty && existing == null
                      ? null
                      : () => Navigator.of(context).pop(true),
                  child: Text('common.save'.tr()),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(categoryRepositoryProvider);
    if (existing == null) {
      await repo.create(
        name: name,
        icon: iconController.text.trim().isEmpty ? '📦' : iconController.text.trim(),
        color: colorToHex(selectedColor),
        type: type,
        parentCategoryId: parentCategoryId,
      );
    } else {
      await repo.update(
        existing.id,
        name: name,
        icon: iconController.text.trim().isEmpty ? '📦' : iconController.text.trim(),
        color: colorToHex(selectedColor),
      );
    }
  }

  Future<void> _confirmDelete(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('categories.deleteCategory'.tr()),
        content: Text('categories.deleteConfirm'.tr(namedArgs: {'name': category.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(categoryRepositoryProvider).delete(category.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('categories.manageCategories'.tr()),
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          tabs: [
            Tab(text: 'transactions.expense'.tr()),
            Tab(text: 'transactions.income'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CategoryList(
            type: CategoryType.expense,
            onAddMain: () => _openEditor(type: CategoryType.expense),
            onAddChild: (parent) => _openEditor(type: CategoryType.expense, parentCategoryId: parent.id),
            onEdit: (c, type) => _openEditor(type: type, existing: c),
            onDelete: _confirmDelete,
          ),
          _CategoryList(
            type: CategoryType.income,
            onAddMain: () => _openEditor(type: CategoryType.income),
            onAddChild: (parent) => _openEditor(type: CategoryType.income, parentCategoryId: parent.id),
            onEdit: (c, type) => _openEditor(type: type, existing: c),
            onDelete: _confirmDelete,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(type: _currentType),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({
    required this.type,
    required this.onAddMain,
    required this.onAddChild,
    required this.onEdit,
    required this.onDelete,
  });

  final CategoryType type;
  final VoidCallback onAddMain;
  final void Function(Category parent) onAddChild;
  final void Function(Category category, CategoryType type) onEdit;
  final void Function(Category category) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(categoryTreeProvider(type));

    return treeAsync.when(
      data: (tree) {
        if (tree.isEmpty) {
          return Center(child: Text('categories.noCategories'.tr()));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: tree.length,
          itemBuilder: (context, index) {
            final node = tree[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: colorFromHex(node.main.color),
                  child: Text(node.main.icon),
                ),
                title: Text(node.main.name),
                children: [
                  for (final child in node.children)
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 32, right: 16),
                      leading: CircleAvatar(
                        backgroundColor: colorFromHex(child.color),
                        radius: 14,
                        child: Text(child.icon, style: const TextStyle(fontSize: 14)),
                      ),
                      title: Text(child.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => onEdit(child, type),
                          ),
                          if (!child.isDefault)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => onDelete(child),
                            ),
                        ],
                      ),
                    ),
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 32, right: 16),
                    leading: const Icon(Icons.add),
                    title: Text('categories.addSubCategory'.tr()),
                    onTap: () => onAddChild(node.main),
                  ),
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text('common.edit'.tr()),
                        onPressed: () => onEdit(node.main, type),
                      ),
                      if (!node.main.isDefault)
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text('common.delete'.tr()),
                          onPressed: () => onDelete(node.main),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('$e')),
    );
  }
}
