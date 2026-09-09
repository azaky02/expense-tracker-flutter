enum AppThemeMode { system, light, dark }

enum CalendarSystem { gregorian, hijri }

class SettingsState {
  const SettingsState({
    this.userName = '',
    this.languageCode = 'ar',
    this.calendar = CalendarSystem.gregorian,
    this.themeMode = AppThemeMode.system,
    this.hasOnboarded = false,
    this.appLockEnabled = false,
    this.biometricEnabled = false,
  });

  final String userName;
  final String languageCode;
  final CalendarSystem calendar;
  final AppThemeMode themeMode;
  final bool hasOnboarded;
  final bool appLockEnabled;
  final bool biometricEnabled;

  SettingsState copyWith({
    String? userName,
    String? languageCode,
    CalendarSystem? calendar,
    AppThemeMode? themeMode,
    bool? hasOnboarded,
    bool? appLockEnabled,
    bool? biometricEnabled,
  }) {
    return SettingsState(
      userName: userName ?? this.userName,
      languageCode: languageCode ?? this.languageCode,
      calendar: calendar ?? this.calendar,
      themeMode: themeMode ?? this.themeMode,
      hasOnboarded: hasOnboarded ?? this.hasOnboarded,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }
}
