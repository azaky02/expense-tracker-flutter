import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_state.dart';

const _kUserName = 'settings.userName';
const _kUserPhone = 'settings.userPhone';
const _kLanguage = 'settings.languageCode';
const _kCalendar = 'settings.calendar';
const _kThemeMode = 'settings.themeMode';
const _kHasOnboarded = 'settings.hasOnboarded';
const _kAppLockEnabled = 'settings.appLockEnabled';
const _kBiometricEnabled = 'settings.biometricEnabled';
const _kDailyReminder = 'settings.dailyReminder';
const _kReminderTimes = 'settings.reminderTimes';
const _kSalaryDay = 'settings.salaryDay';

/// Plain (non-secret) user preferences persisted via shared_preferences. Security-relevant
/// secrets (PIN hash, DB key) live in SecureStorageService instead — see core/security/.
class SettingsNotifier extends Notifier<SettingsState> {
  late SharedPreferences _prefs;

  @override
  SettingsState build() {
    _load();
    return const SettingsState();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      userName: _prefs.getString(_kUserName) ?? '',
      userPhone: _prefs.getString(_kUserPhone) ?? '',
      loaded: true,
      languageCode: _prefs.getString(_kLanguage) ?? 'ar',
      calendar: CalendarSystem.values[_prefs.getInt(_kCalendar) ?? 0],
      themeMode: AppThemeMode.values[_prefs.getInt(_kThemeMode) ?? 0],
      hasOnboarded: _prefs.getBool(_kHasOnboarded) ?? false,
      appLockEnabled: _prefs.getBool(_kAppLockEnabled) ?? false,
      biometricEnabled: _prefs.getBool(_kBiometricEnabled) ?? false,
      dailyReminder: _prefs.getBool(_kDailyReminder) ?? false,
      reminderTimes: _prefs.getStringList(_kReminderTimes) ?? SettingsState.defaultReminderTimes,
      salaryDay: _prefs.getInt(_kSalaryDay) ?? 0,
    );
  }

  Future<void> setUserName(String name) async {
    state = state.copyWith(userName: name);
    await _prefs.setString(_kUserName, name);
  }

  Future<void> setUserPhone(String phone) async {
    state = state.copyWith(userPhone: phone);
    await _prefs.setString(_kUserPhone, phone);
  }

  Future<void> setLanguage(String code) async {
    state = state.copyWith(languageCode: code);
    await _prefs.setString(_kLanguage, code);
  }

  Future<void> setCalendar(CalendarSystem calendar) async {
    state = state.copyWith(calendar: calendar);
    await _prefs.setInt(_kCalendar, calendar.index);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setInt(_kThemeMode, mode.index);
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(hasOnboarded: true);
    await _prefs.setBool(_kHasOnboarded, true);
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    state = state.copyWith(appLockEnabled: enabled);
    await _prefs.setBool(_kAppLockEnabled, enabled);
  }

  Future<void> setDailyReminder(bool enabled) async {
    state = state.copyWith(dailyReminder: enabled);
    await _prefs.setBool(_kDailyReminder, enabled);
  }

  Future<void> setReminderTimes(List<String> times) async {
    state = state.copyWith(reminderTimes: times);
    await _prefs.setStringList(_kReminderTimes, times);
  }

  Future<void> setSalaryDay(int day) async {
    state = state.copyWith(salaryDay: day);
    await _prefs.setInt(_kSalaryDay, day);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    state = state.copyWith(biometricEnabled: enabled);
    await _prefs.setBool(_kBiometricEnabled, enabled);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
