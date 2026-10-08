import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/db/tables.dart';
import '../../../../core/theme/ds_tokens.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/widgets/ds_widgets.dart';
import '../../data/transaction_models.dart';

/// Sign and colour of a transaction's amount: red out, green in, neutral for transfers/amanat.
(double, Color) signedAmount(BuildContext context, TransactionWithDetails item) {
  final t = item.transaction;
  final scheme = Theme.of(context).colorScheme;
  return switch (t.type) {
    TransactionType.expense => (-t.amount, scheme.error),
    TransactionType.income => (t.amount, scheme.secondary),
    TransactionType.transfer => (t.amount, scheme.primary),
    TransactionType.trustIn => (t.amount, DS.warning),
    TransactionType.trustOut => (-t.amount, DS.warning),
  };
}

/// One transaction row (dashboard, list, account details).
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.item, this.onTap, this.onLongPress, this.onDoubleTap, this.showDate = false});
  final TransactionWithDetails item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final t = item.transaction;
    final theme = Theme.of(context);
    final (amount, color) = signedAmount(context, item);
    final isTransfer = t.type == TransactionType.transfer;
    final title = isTransfer
        ? 'transactions.transferTitle'.tr(namedArgs: {'from': item.accountName ?? '—', 'to': item.toAccountName ?? '—'})
        : (t.beneficiaryName?.isNotEmpty ?? false)
            ? t.beneficiaryName!
            : item.categoryName;
    final subtitle = [
      if (!isTransfer) item.categoryName,
      if (!isTransfer && item.accountName != null) item.accountName!,
      if (showDate) DateFormat.MMMd(context.locale.languageCode).format(t.date),
    ].where((s) => s.isNotEmpty && s != title).join(' · ');

    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(DS.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(children: [
            IconBubble(
              emoji: isTransfer ? null : item.categoryIcon,
              icon: isTransfer ? Icons.swap_horiz : null,
              color: isTransfer ? theme.colorScheme.primary : colorFromHex(item.categoryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              AmountText(amount, color: color, size: 14, signed: !isTransfer),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (t.note != null && t.note!.isNotEmpty)
                  Icon(Icons.sticky_note_2_outlined, size: 13, color: theme.colorScheme.onSurfaceVariant),
                if (t.attachmentUri != null) Icon(Icons.attach_file, size: 13, color: theme.colorScheme.onSurfaceVariant),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// "‹ أكتوبر 2026 ›" month switcher.
class MonthSelector extends StatelessWidget {
  const MonthSelector({super.key, required this.month, required this.onChanged, this.light = false});
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  /// White text for use on dark/hero backgrounds.
  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final label = DateFormat.yMMMM(context.locale.languageCode).format(month);
    final isCurrent = month.year == DateTime.now().year && month.month == DateTime.now().month;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.arrow_back_ios, size: 16, color: color),
          onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
        ),
        Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color)),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.arrow_forward_ios, size: 16, color: isCurrent ? color.withValues(alpha: 0.3) : color),
          onPressed: isCurrent ? null : () => onChanged(DateTime(month.year, month.month + 1)),
        ),
      ],
    );
  }
}
