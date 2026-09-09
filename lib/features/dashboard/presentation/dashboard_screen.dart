import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/settings_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final greeting = settings.userName.isNotEmpty
        ? 'dashboard.greeting'.tr(namedArgs: {'name': settings.userName})
        : 'dashboard.greetingGeneric'.tr();

    return Scaffold(
      appBar: AppBar(
        title: Text(greeting),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.push('/reports'),
          ),
        ],
      ),
      body: Center(
        child: Text('dashboard.totalSpentThisMonth'.tr()),
      ),
    );
  }
}
