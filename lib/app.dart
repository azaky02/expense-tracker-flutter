import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/db/database_provider.dart';
import 'core/router/app_router.dart';
import 'core/security/lock_provider.dart';
import 'core/settings/settings_provider.dart';
import 'core/settings/settings_state.dart';
import 'core/theme/app_theme.dart';

class ExpenseTrackerApp extends ConsumerStatefulWidget {
  const ExpenseTrackerApp({super.key});

  @override
  ConsumerState<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends ConsumerState<ExpenseTrackerApp> {
  AppLifecycleLockObserver? _lockObserver;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lockObserver == null) {
      _lockObserver = AppLifecycleLockObserver(
        isAppLockEnabled: () => ref.read(settingsProvider).appLockEnabled,
        onLock: () => ref.read(lockProvider.notifier).lock(),
      );
      WidgetsBinding.instance.addObserver(_lockObserver!);
    }
  }

  @override
  void dispose() {
    if (_lockObserver != null) {
      WidgetsBinding.instance.removeObserver(_lockObserver!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dbReady = ref.watch(databaseReadyProvider);
    final settings = ref.watch(settingsProvider);

    return dbReady.when(
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, stack) => MaterialApp(
        home: Scaffold(body: Center(child: Text('Failed to open database: $error'))),
      ),
      data: (_) {
        final router = ref.watch(routerProvider);
        return MaterialApp.router(
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: switch (settings.themeMode) {
            AppThemeMode.system => ThemeMode.system,
            AppThemeMode.light => ThemeMode.light,
            AppThemeMode.dark => ThemeMode.dark,
          },
        );
      },
    );
  }
}
