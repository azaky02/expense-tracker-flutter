import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/db/database_provider.dart';
import 'core/router/app_router.dart';
import 'core/security/lock_provider.dart';
import 'core/settings/settings_provider.dart';
import 'core/settings/settings_state.dart';
import 'core/sync/sync_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/lock/presentation/unlock_screen.dart';
import 'features/associations/data/association_repository.dart';
import 'features/cars/data/car_reminders.dart';
import 'features/installments/data/installment_reminders.dart';
import 'features/settings/data/general_reminders.dart';

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
        lockAfter: () => Duration(minutes: ref.read(settingsProvider).lockAfterMinutes),
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
      // The splash/error apps carry the same localization delegates as the real one, so the
      // switch to the router app never builds a frame without translations (which crashed
      // `.tr(context: …)` lookups such as the bottom navigation labels).
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, stack) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: Scaffold(body: Center(child: Text('Failed to open database: $error'))),
      ),
      data: (_) {
        // Starts background sync (when signed in) for the whole app lifetime.
        ref.watch(syncControllerProvider);
        // Keeps installment reminders scheduled as plans and payments change.
        ref.watch(installmentRemindersProvider);
        ref.watch(carRemindersProvider);
        ref.watch(generalRemindersProvider);
        ref.watch(salaryIncomeProvider);
        ref.watch(associationRemindersProvider);
        final router = ref.watch(routerProvider);
        return MaterialApp.router(
          routerConfig: router,
          // The PIN screen covers the app instead of replacing the current page, so a form that
          // was being filled in is still there after unlocking.
          builder: (context, child) {
            final locked = settings.appLockEnabled && settings.hasOnboarded && !ref.watch(lockProvider) && ref.watch(splashDoneProvider);
            final app = Stack(
              children: [
                child ?? const SizedBox(),
                if (locked) const Positioned.fill(child: LockGate()),
              ],
            );
            // In a wide browser window (PWA on a computer) keep the phone layout, centred.
            final width = MediaQuery.sizeOf(context).width;
            if (!kIsWeb || width <= 600) return app;
            return ColoredBox(
              color: const Color(0xFF050B08),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(size: Size(480, MediaQuery.sizeOf(context).height)),
                    child: ClipRect(child: app),
                  ),
                ),
              ),
            );
          },
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
