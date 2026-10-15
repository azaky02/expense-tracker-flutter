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
const _kUserEmail = 'settings.userEmail';
const _kSalaryAmount = 'settings.salaryAmount';
const _kDisabledModules = 'settings.disabledModules';
const _kHiddenModules = 'settings.hiddenModules';
const _kLockAfter = 'settings.lockAfterMinutes';

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
      userEmail: _prefs.getString(_kUserEmail) ?? '',
      salaryAmount: _prefs.getDouble(_kSalaryAmount) ?? 0,
      disabledModules: _prefs.getStringList(_kDisabledModules) ?? const [],
      hiddenModules: _prefs.getStringList(_kHiddenModules) ?? const [],
      lockAfterMinutes: _prefs.getInt(_kLockAfter) ?? 5,
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

  Future<void> setUserEmail(String email) async {
    state = state.copyWith(userEmail: email);
    await _prefs.setString(_kUserEmail, email);
  }

  Future<void> setSalaryAmount(double amount) async {
    state = state.copyWith(salaryAmount: amount);
    await _prefs.setDouble(_kSalaryAmount, amount);
  }

  /// [enabled] false switches the section off everywhere; [shown] false only hides it on Home.
  Future<void> setModule(String key, {bool? enabled, bool? shown}) async {
    final disabled = [...state.disabledModules];
    final hidden = [...state.hiddenModules];
    if (enabled != null) {
      disabled.remove(key);
      if (!enabled) disabled.add(key);
    }
    if (shown != null) {
      hidden.remove(key);
      if (!shown) hidden.add(key);
    }
    state = state.copyWith(disabledModules: disabled, hiddenModules: hidden);
    await _prefs.setStringList(_kDisabledModules, disabled);
    await _prefs.setStringList(_kHiddenModules, hidden);
  }

  Future<void> setLockAfterMinutes(int minutes) async {
    state = state.copyWith(lockAfterMinutes: minutes);
    await _prefs.setInt(_kLockAfter, minutes);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    state = state.copyWith(biometricEnabled: enabled);
    await _prefs.setBool(_kBiometricEnabled, enabled);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
