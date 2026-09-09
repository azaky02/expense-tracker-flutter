import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('nav.settings'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            initialValue: settings.userName,
            decoration: InputDecoration(labelText: 'settings.yourName'.tr()),
            onFieldSubmitted: (value) =>
                ref.read(settingsProvider.notifier).setUserName(value),
          ),
        ],
      ),
    );
  }
}
