import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'beneficiary_providers.dart';

/// Dropdown-style list of known people with search and "add new". Returns the chosen name, an
/// empty string when "none" is picked (only offered when [allowNone]), or null if dismissed.
Future<String?> showPersonPicker(
  BuildContext context, {
  required String title,
  String? selected,
  bool allowNone = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.7,
      child: _PersonPickerSheet(title: title, selected: selected, allowNone: allowNone),
    ),
  );
}

class _PersonPickerSheet extends ConsumerStatefulWidget {
  const _PersonPickerSheet({required this.title, this.selected, required this.allowNone});
  final String title;
  final String? selected;
  final bool allowNone;

  @override
  ConsumerState<_PersonPickerSheet> createState() => _PersonPickerSheetState();
}

class _PersonPickerSheetState extends ConsumerState<_PersonPickerSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(allBeneficiariesProvider).value ?? const <String>[];
    final theme = Theme.of(context);
    final typed = _controller.text.trim();
    final matches = typed.isEmpty
        ? names
        : names.where((n) => n.toLowerCase().contains(typed.toLowerCase())).toList();
    final exists = names.any((n) => n.toLowerCase() == typed.toLowerCase());

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(widget.title, style: theme.textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.done,
              onSubmitted: (v) {
                final t = v.trim();
                if (t.isNotEmpty) Navigator.of(context).pop(t);
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'transactions.searchOrAddPerson'.tr(context: context),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (typed.isNotEmpty && !exists)
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: Text('transactions.addPerson'.tr(namedArgs: {'name': typed}, context: context)),
                    onTap: () => Navigator.of(context).pop(typed),
                  ),
                if (widget.allowNone && typed.isEmpty)
                  ListTile(
                    leading: const Icon(Icons.person_off_outlined),
                    title: Text('transactions.noPerson'.tr(context: context)),
                    onTap: () => Navigator.of(context).pop(''),
                  ),
                for (final n in matches)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(n),
                    trailing: n == widget.selected ? Icon(Icons.check, color: theme.colorScheme.secondary) : null,
                    onTap: () => Navigator.of(context).pop(n),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
