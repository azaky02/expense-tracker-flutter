import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../sync/sync_controller.dart';
import '../theme/ds_tokens.dart';
import '../utils/currency.dart';

/// White card with soft shadow and 14 px radius (the basic surface of every screen).
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color, this.margin});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(DS.radius),
        border: theme.brightness == Brightness.dark ? Border.all(color: theme.colorScheme.outline) : null,
        boxShadow: DS.softShadow(theme.brightness),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(DS.radius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Money is always shown with its currency, in Inter, with an optional sign and colour.
class AmountText extends StatelessWidget {
  const AmountText(this.amount, {super.key, this.currency = 'EGP', this.color, this.size = 15, this.signed = false, this.weight = FontWeight.w700});
  final double amount;
  final String currency;
  final Color? color;
  final double size;
  final bool signed;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final sign = signed ? (amount > 0 ? '+' : amount < 0 ? '-' : '') : (amount < 0 ? '-' : '');
    final style = GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color ?? Theme.of(context).colorScheme.onSurface);
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$sign${formatAmount(amount.abs())}', style: style),
          TextSpan(text: ' $currency', style: style.copyWith(fontSize: size * 0.62, fontWeight: FontWeight.w600)),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Section title with an optional trailing action ("عرض الكل").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Round tinted icon (category, account, action).
class IconBubble extends StatelessWidget {
  const IconBubble({super.key, this.icon, this.emoji, required this.color, this.size = 42});
  final IconData? icon;
  final String? emoji;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
      child: emoji != null && emoji!.isNotEmpty
          ? Text(emoji!, style: TextStyle(fontSize: size * 0.45))
          : Icon(icon ?? Icons.circle_outlined, color: color, size: size * 0.5),
    );
  }
}

/// Small coloured status label (Pending / Confirmed / Rejected / Offline ...).
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, required this.color, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
        Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Empty state: clear message + a call to action to create the first item (UX §18).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBubble(icon: icon, color: theme.colorScheme.primary, size: 72),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(180, 46)),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Error state: understandable message + Retry (UX §18).
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          IconBubble(icon: Icons.error_outline, color: theme.colorScheme.error, size: 64),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(140, 44)),
              onPressed: onRetry,
              child: Text('common.retry'.tr(context: context)),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Loading placeholder: grey blocks instead of a frozen screen (UX §18).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          Container(
            height: 64,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(DS.radius)),
          ),
      ],
    );
  }
}

/// Sync status for signed-in users: syncing / synced / offline-or-error. Quiet when all is well.
class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(syncControllerProvider);
    if (!s.signedIn) return const SizedBox.shrink();
    final (icon, color, label) = switch (s.status) {
      SyncStatus.syncing => (Icons.sync, DS.primary, 'sync.syncing'),
      SyncStatus.error => (
          s.errorCode == 'network' ? Icons.cloud_off_outlined : Icons.error_outline,
          DS.warning,
          s.errorCode == 'network' ? 'sync.offline' : 'sync.failed'
        ),
      _ => (Icons.cloud_done_outlined, DS.success, 'sync.synced'),
    };
    return Tooltip(
      message: label.tr(context: context),
      child: IconButton(
        onPressed: () => ref.read(syncControllerProvider.notifier).syncNow(),
        icon: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

/// A form field label above its input (mockups put labels above fields).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );
}

/// Tappable box that looks like an input with a trailing chevron (pickers).
class PickerField extends StatelessWidget {
  const PickerField({super.key, required this.text, this.placeholder = false, this.leading, this.trailingIcon = Icons.keyboard_arrow_down, required this.onTap});
  final String text;
  final bool placeholder;
  final Widget? leading;
  final IconData trailingIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DS.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(DS.radius),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: placeholder ? TextStyle(color: theme.colorScheme.onSurfaceVariant) : null,
            ),
          ),
          Icon(trailingIcon, color: theme.colorScheme.onSurfaceVariant, size: 20),
        ]),
      ),
    );
  }
}

/// Big centred amount input with the currency (amount is always the first field, UX §19).
class AmountField extends StatelessWidget {
  const AmountField({super.key, required this.controller, this.onChanged, this.autofocus = false, this.currency = 'EGP'});
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.start,
      textDirection: ui.TextDirection.ltr,
      style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: '0.00',
        suffixText: currency,
        suffixStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
