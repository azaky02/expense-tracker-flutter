import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_state.dart';

const _kUserName = 'settings.userName';
const _kLanguage = 'settings.languageCode';
const _kCalendar = 'settings.calendar';
const _kThemeMode = 'settings.themeMode';
const _kHasOnboarded = 'settings.hasOnboarded';
const _kAppLockEnabled = 'settings.appLockEnabled';
const _kBiometricEnabled = 'settings.biometricEnabled';

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
      languageCode: _prefs.getString(_kLanguage) ?? 'ar',
      calendar: CalendarSystem.values[_prefs.getInt(_kCalendar) ?? 0],
      themeMode: AppThemeMode.values[_prefs.getInt(_kThemeMode) ?? 0],
      hasOnboarded: _prefs.getBool(_kHasOnboarded) ?? false,
      appLockEnabled: _prefs.getBool(_kAppLockEnabled) ?? false,
      biometricEnabled: _prefs.getBool(_kBiometricEnabled) ?? false,
    );
  }

  Future<void> setUserName(String name) async {
    state = state.copyWith(userName: name);
    await _prefs.setString(_kUserName, name);
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

  Future<void> setBiometricEnabled(bool enabled) async {
    state = state.copyWith(biometricEnabled: enabled);
    await _prefs.setBool(_kBiometricEnabled, enabled);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
