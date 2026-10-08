import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/settings_provider.dart';
import '../../../core/settings/settings_state.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../people/presentation/people_screen.dart';

const _releaseCode = String.fromEnvironment('RELEASE_CODE', defaultValue: 'dev');
const _appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '');

/// More (UI/UX §17): profile & account, management screens, preferences, about.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final sync = ref.watch(syncControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('nav.more'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          AppCard(
            onTap: () => context.push(sync.signedIn ? '/account' : '/login'),
            child: Row(children: [
              PersonAvatar(name: settings.userName.isEmpty ? '؟' : settings.userName, color: DS.primary, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(settings.userName.isEmpty ? 'settings.noName'.tr() : settings.userName, style: theme.textTheme.titleMedium),
                  Text(
                    sync.signedIn ? sync.session!.email : 'settings.notSignedIn'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ]),
              ),
              if (sync.signedIn) const SyncStatusBadge() else Text('auth.signIn'.tr(), style: TextStyle(color: theme.colorScheme.primary)),
            ]),
          ),
          _Section('settings.sectionManage'.tr(), [
            _Item(Icons.account_balance_wallet_outlined, 'accounts.title'.tr(), () => context.push('/accounts')),
            _Item(Icons.credit_card, 'settings.cards'.tr(), () => context.push('/cards')),
            _Item(Icons.category_outlined, 'categories.manageCategories'.tr(), () => context.push('/categories')),
            _Item(Icons.pie_chart_outline, 'budgets.screenTitle'.tr(), () => context.push('/budgets')),
            _Item(Icons.bar_chart_rounded, 'reports.title'.tr(), () => context.push('/reports')),
            _Item(Icons.notifications_outlined, 'notifications.title'.tr(), () => context.push('/notifications')),
          ]),
          _Section('settings.sectionAccount'.tr(), [
            _Item(Icons.cloud_sync_outlined, 'settings.accountSync'.tr(), () => context.push(sync.signedIn ? '/account' : '/login')),
            _Item(Icons.person_outline, 'settings.yourName'.tr(), () => _editName(context, ref, settings.userName),
                trailing: settings.userName),
          ]),
          _Section('settings.sectionPreferences'.tr(), [
            _Item(Icons.language, 'settings.language'.tr(), () async {
              final code = context.locale.languageCode == 'ar' ? 'en' : 'ar';
              await ref.read(settingsProvider.notifier).setLanguage(code);
              if (context.mounted) await context.setLocale(Locale(code));
            }, trailing: context.locale.languageCode == 'ar' ? 'العربية' : 'English'),
            _Item(Icons.dark_mode_outlined, 'settings.theme'.tr(), () => _pickTheme(context, ref, settings.themeMode),
                trailing: 'settings.themeMode.${settings.themeMode.name}'.tr()),
            _Item(Icons.payments_outlined, 'settings.currency'.tr(), null, trailing: 'EGP'),
          ]),
          _Section('settings.sectionSecurity'.tr(), [
            _Item(Icons.lock_outline, 'settings.appLock'.tr(), () => context.push('/security'),
                trailing: (settings.appLockEnabled ? 'security.on' : 'security.off').tr()),
            _Item(Icons.backup_outlined, 'settings.backup'.tr(), () => context.push('/backup')),
          ]),
          _Section('settings.sectionAbout'.tr(), [
            _Item(Icons.info_outline, 'settings.version'.tr(), null,
                trailing: _appVersion.isEmpty ? _releaseCode : '$_appVersion ($_releaseCode)'),
          ]),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, String current) async {
    final c = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('settings.yourName'.tr()),
        content: TextField(controller: c, autofocus: true, decoration: InputDecoration(hintText: 'settings.yourNamePlaceholder'.tr())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(settingsProvider.notifier).setUserName(c.text.trim());
    c.dispose();
  }

  Future<void> _pickTheme(BuildContext context, WidgetRef ref, AppThemeMode current) async {
    final mode = await showModalBottomSheet<AppThemeMode>(
      context: context,
      builder: (ctx) => SafeArea(
        child: RadioGroup<AppThemeMode>(
          groupValue: current,
          onChanged: (m) => Navigator.pop(ctx, m),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final m in AppThemeMode.values) RadioListTile<AppThemeMode>(value: m, title: Text('settings.themeMode.${m.name}'.tr())),
          ]),
        ),
      ),
    );
    if (mode != null) await ref.read(settingsProvider.notifier).setThemeMode(mode);
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.items);
  final String title;
  final List<_Item> items;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(title),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          for (var i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1) const Divider(indent: 56, height: 1),
          ],
        ]),
      ),
    ]);
  }
}

class _Item extends StatelessWidget {
  const _Item(this.icon, this.title, this.onTap, {this.trailing});
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: IconBubble(icon: icon, color: theme.colorScheme.primary, size: 36),
      title: Text(title),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (trailing != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(trailing!, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        if (onTap != null) Icon(Icons.arrow_forward_ios, size: 14, color: theme.colorScheme.onSurfaceVariant),
      ]),
      onTap: onTap,
    );
  }
}
