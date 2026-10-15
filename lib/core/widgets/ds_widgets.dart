import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_controller.dart';
import '../theme/app_theme.dart';
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
  const AmountText(
    this.amount, {
    super.key,
    this.currency = 'EGP',
    this.color,
    this.size = 15,
    this.signed = false,
    this.weight = FontWeight.w700,
  });
  final double amount;
  final String currency;
  final Color? color;
  final double size;
  final bool signed;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final sign = signed
        ? (amount > 0
              ? '+'
              : amount < 0
              ? '-'
              : '')
        : (amount < 0 ? '-' : '');
    final style = AppTheme.numbers(fontSize: size, fontWeight: weight, color: color ?? Theme.of(context).colorScheme.onSurface);
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$sign${formatAmount(amount.abs())}', style: style),
            TextSpan(
              text: ' $currency',
              style: style.copyWith(fontSize: size * 0.62, fontWeight: FontWeight.w600),
            ),
          ],
        ),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(
            text,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
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
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
          ],
        ),
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
        s.errorCode == 'network' ? 'sync.offline' : 'sync.failed',
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
    padding: const EdgeInsets.only(top: 10, bottom: 4),
    child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge),
  );
}

/// Two (or more) labelled fields side by side, e.g. date | odometer. Each entry is (label, field).
class FieldRow extends StatelessWidget {
  const FieldRow(this.fields, {super.key, this.flex});
  final List<(String, Widget)> fields;

  /// Optional relative widths, one per field.
  final List<int>? flex;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < fields.length; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(
          flex: flex?[i] ?? 1,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [FieldLabel(fields[i].$1), fields[i].$2]),
        ),
      ],
    ],
  );
}

/// Tappable box that looks like an input with a trailing chevron (pickers).
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.text,
    this.placeholder = false,
    this.leading,
    this.trailingIcon = Icons.keyboard_arrow_down,
    required this.onTap,
    this.subtitle,
  });
  final String text;

  /// Small second line (e.g. an account's balance).
  final String? subtitle;
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(DS.radius),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    overflow: TextOverflow.ellipsis,
                    style: placeholder ? TextStyle(color: theme.colorScheme.onSurfaceVariant) : null,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            Icon(trailingIcon, color: theme.colorScheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Big centred amount input with the currency (amount is always the first field, UX §19).
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.onChanged,
    this.autofocus = false,
    this.currency = 'EGP',
    this.compact = false,
  });
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final String currency;

  /// Normal-height version for use next to other fields in a [FieldRow].
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const [AsciiDigitsFormatter()],
      textAlign: TextAlign.start,
      textDirection: ui.TextDirection.ltr,
      style: AppTheme.numbers(fontSize: compact ? 16 : 22, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: '0.00',
        suffixText: currency,
        suffixStyle: AppTheme.numbers(
          fontSize: compact ? 12 : 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Collapsible "Additional details (optional)" card for the less used fields of a form.
class OptionalSection extends StatefulWidget {
  const OptionalSection({super.key, required this.children, this.initiallyExpanded = false, this.summary});
  final List<Widget> children;
  final bool initiallyExpanded;

  /// What is already filled in, shown while collapsed (e.g. "ملاحظة · مرفق").
  final String? summary;

  @override
  State<OptionalSection> createState() => _OptionalSectionState();
}

class _OptionalSectionState extends State<OptionalSection> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(DS.radius),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(DS.radius),
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('common.moreDetails'.tr(), style: theme.textTheme.titleSmall),
                          if (!_open && (widget.summary?.isNotEmpty ?? false))
                            Text(
                              widget.summary!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(Icons.keyboard_arrow_down, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.children),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Form body with the save button fixed at the bottom of the screen (above the keyboard).
class StickySaveLayout extends StatelessWidget {
  const StickySaveLayout({
    super.key,
    required this.children,
    required this.button,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 24),
  });
  final List<Widget> children;
  final Widget button;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(padding: padding, children: children),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.6))),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SafeArea(
            top: false,
            child: SizedBox(width: double.infinity, child: button),
          ),
        ),
      ],
    );
  }
}

/// Curved green header for forms: back button, title, optional confirm (✓) and extra actions.
class BrandFormAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandFormAppBar({super.key, required this.title, this.onSave, this.actions = const []});
  final String title;
  final VoidCallback? onSave;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 14);

  @override
  Widget build(BuildContext context) {
    Widget circle(IconData icon, VoidCallback? onTap, {bool gold = false}) => Material(
      color: Colors.white,
      shape: CircleBorder(side: gold ? const BorderSide(color: DS.gold, width: 1.5) : BorderSide.none),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, color: onTap == null ? Colors.black26 : DS.primary, size: 22),
        ),
      ),
    );
    return Container(
      decoration: const BoxDecoration(
        gradient: DS.navyGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight + 14,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                circle(Icons.arrow_back_ios_new_rounded, () => Navigator.of(context).maybePop()),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
                ...actions.map(
                  (a) => IconTheme(
                    data: const IconThemeData(color: Colors.white),
                    child: a,
                  ),
                ),
                if (onSave != null || actions.isEmpty) circle(Icons.check_rounded, onSave, gold: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A form field in its own card: icon and label on one side, the field on the other.
class FormRowCard extends StatelessWidget {
  const FormRowCard({super.key, required this.icon, required this.label, required this.child, this.labelWidth = 92, this.iconColor});
  final IconData icon;
  final String label;
  final Widget child;
  final double labelWidth;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(DS.radius),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.7)),
        boxShadow: DS.softShadow(theme.brightness),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21, color: iconColor ?? theme.colorScheme.primary),
          const SizedBox(width: 6),
          SizedBox(
            width: labelWidth,
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Large save button with a gold edge (bottom of forms).
class BigSaveButton extends StatelessWidget {
  const BigSaveButton({super.key, required this.label, required this.onPressed, this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: DS.primary,
        foregroundColor: Colors.white,
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: onPressed == null ? Colors.transparent : DS.gold, width: 1.5),
        ),
      ),
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.save_rounded),
      label: Text(label),
    );
  }
}
