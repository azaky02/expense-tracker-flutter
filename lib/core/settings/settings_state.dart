enum AppThemeMode { system, light, dark }

enum CalendarSystem { gregorian, hijri }

class SettingsState {
  const SettingsState({
    this.userName = '',
    this.userPhone = '',
    this.loaded = false,
    this.languageCode = 'ar',
    this.calendar = CalendarSystem.gregorian,
    this.themeMode = AppThemeMode.system,
    this.hasOnboarded = false,
    this.appLockEnabled = false,
    this.biometricEnabled = false,
    this.dailyReminder = false,
    this.reminderTimes = defaultReminderTimes,
    this.salaryDay = 0,
    this.userEmail = '',
    this.salaryAmount = 0,
    this.disabledModules = const [],
    this.hiddenModules = const [],
  });

  static const defaultReminderTimes = ['09:00', '15:00', '21:00'];

  final String userName;
  final String userPhone;

  /// False until the stored preferences have been read.
  final bool loaded;
  final String languageCode;
  final CalendarSystem calendar;
  final AppThemeMode themeMode;
  final bool hasOnboarded;
  final bool appLockEnabled;
  final bool biometricEnabled;

  /// "Record your expenses" reminder, up to three times a day (HH:mm, empty = off).
  final bool dailyReminder;
  final List<String> reminderTimes;

  /// Day of the month the salary arrives (1-31), 0 = not set.
  final int salaryDay;

  /// For password recovery (sending a reset code once a mail server is set up).
  final String userEmail;

  /// Monthly salary; when set it is recorded as income on [salaryDay] automatically.
  final double salaryAmount;

  /// Sections switched off (not used at all) / not shown on the home screen. See [AppModule].
  final List<String> disabledModules;
  final List<String> hiddenModules;

  bool moduleEnabled(String key) => !disabledModules.contains(key);
  bool moduleShown(String key) => moduleEnabled(key) && !hiddenModules.contains(key);

  SettingsState copyWith({
    String? userName,
    String? userPhone,
    String? languageCode,
    CalendarSystem? calendar,
    AppThemeMode? themeMode,
    bool? hasOnboarded,
    bool? appLockEnabled,
    bool? biometricEnabled,
    bool? dailyReminder,
    List<String>? reminderTimes,
    int? salaryDay,
    String? userEmail,
    double? salaryAmount,
    List<String>? disabledModules,
    List<String>? hiddenModules,
  }) {
    return SettingsState(
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      loaded: loaded,
      languageCode: languageCode ?? this.languageCode,
      calendar: calendar ?? this.calendar,
      themeMode: themeMode ?? this.themeMode,
      hasOnboarded: hasOnboarded ?? this.hasOnboarded,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      dailyReminder: dailyReminder ?? this.dailyReminder,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      salaryDay: salaryDay ?? this.salaryDay,
      userEmail: userEmail ?? this.userEmail,
      salaryAmount: salaryAmount ?? this.salaryAmount,
      disabledModules: disabledModules ?? this.disabledModules,
      hiddenModules: hiddenModules ?? this.hiddenModules,
    );
  }
}

/// Sections of the app that can be switched off or hidden from the home screen.
enum AppModule {
  cars('cars', 'cars.title'),
  installments('installments', 'installments.title'),
  associations('associations', 'associations.title'),
  custody('custody', 'modules.custody'),
  budgets('budgets', 'budgets.screenTitle'),
  stats('stats', 'stats.title'),
  reports('reports', 'reports.title'),
  accounts('accounts', 'accounts.title');

  const AppModule(this.key, this.labelKey);
  final String key;
  final String labelKey;
}
