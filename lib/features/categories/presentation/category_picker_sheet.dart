import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart' hide Card;
import '../../../core/db/tables.dart';
import '../data/category_repository.dart';
import 'category_editor.dart';
import 'category_providers.dart';

/// Two-column category picker: main categories on one side, the chosen main's sub-categories on
/// the other, with "add" buttons on top of each column. Returns the chosen category id (the
/// sub-category when one is picked, otherwise the main category), or null if dismissed.
Future<int?> showCategoryPicker(BuildContext context, {required CategoryType type, int? selectedId}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.75,
      child: _CategoryPickerSheet(type: type, selectedId: selectedId),
    ),
  );
}

class _CategoryPickerSheet extends ConsumerStatefulWidget {
  const _CategoryPickerSheet({required this.type, this.selectedId});
  final CategoryType type;
  final int? selectedId;

  @override
  ConsumerState<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<_CategoryPickerSheet> {
  int? _mainId;
  int? _subId;
  bool _initialised = false;

  void _initFrom(List<CategoryTreeNode> tree) {
    if (_initialised) return;
    _initialised = true;
    final id = widget.selectedId;
    if (id == null) return;
    for (final node in tree) {
      if (node.main.id == id) {
        _mainId = id;
      } else if (node.children.any((c) => c.id == id)) {
        _mainId = node.main.id;
        _subId = id;
      }
    }
  }

  Future<void> _addMain() async {
    final id = await showCategoryEditor(context, ref, type: widget.type);
    if (id != null) {
      setState(() {
        _mainId = id;
        _subId = null;
      });
    }
  }

  Future<void> _addSub() async {
    final main = _mainId;
    if (main == null) return;
    final id = await showCategoryEditor(context, ref, type: widget.type, parentCategoryId: main);
    if (id != null) setState(() => _subId = id);
  }

  @override
  Widget build(BuildContext context) {
    final tree = ref.watch(categoryTreeProvider(widget.type)).value ?? const <CategoryTreeNode>[];
    _initFrom(tree);
    final theme = Theme.of(context);

    CategoryTreeNode? node;
    for (final n in tree) {
      if (n.main.id == _mainId) node = n;
    }
    Category? sub;
    for (final c in node?.children ?? const <Category>[]) {
      if (c.id == _subId) sub = c;
    }
    final path = node == null ? '—' : (sub == null ? node.main.name : '${node.main.name} / ${sub.name}');

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(path, style: theme.textTheme.titleMedium),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: node == null ? null : () => Navigator.of(context).pop(_subId ?? _mainId),
                  icon: const Icon(Icons.check),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Column(
                    addLabel: 'categories.addCategory'.tr(context: context),
                    onAdd: _addMain,
                    children: [
                      for (final n in tree)
                        _Row(
                          icon: n.main.icon,
                          label: n.main.name,
                          selected: n.main.id == _mainId,
                          onTap: () => setState(() {
                            _mainId = n.main.id;
                            _subId = null;
                          }),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _Column(
                    addLabel: 'categories.addSubCategory'.tr(context: context),
                    onAdd: node == null ? null : _addSub,
                    children: [
                      if (node != null)
                        _Row(
                          icon: '',
                          label: '—',
                          selected: _subId == null,
                          onTap: () => setState(() => _subId = null),
                        ),
                      for (final c in node?.children ?? const <Category>[])
                        _Row(
                          icon: c.icon,
                          label: c.name,
                          selected: c.id == _subId,
                          onTap: () => setState(() => _subId = c.id),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.addLabel, required this.onAdd, required this.children});
  final String addLabel;
  final VoidCallback? onAdd;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: OutlinedButton(onPressed: onAdd, child: Text(addLabel)),
        ),
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 8), children: children)),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.selected, required this.onTap});
  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? scheme.secondary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                if (icon.isNotEmpty) ...[Text(icon, style: const TextStyle(fontSize: 18)), const SizedBox(width: 8)],
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? scheme.onSecondary : scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
