import 'package:flutter/material.dart';

class SegmentedOption<T> {
  const SegmentedOption({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final String? icon;
}

/// Two-option toggle matching the wireframes' Expense/Income and Cash/Card segmented rows.
class SegmentedToggle<T> extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.selectedColor,
  });

  final List<SegmentedOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = selectedColor ?? theme.colorScheme.secondary;
    return Row(
      children: [
        for (final option in options)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onChanged(option.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: option.value == value
                        ? accent
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (option.icon != null) ...[
                        Text(option.icon!, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        option.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: option.value == value
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
