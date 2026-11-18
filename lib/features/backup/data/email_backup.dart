import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import 'backup_service.dart';

/// Daily encrypted backup sent to the user's e-mail through Brevo (the user's own account and key).
///
/// Secrets (the Brevo key and the backup password) stay in the device's secure storage and never
/// in the code or SharedPreferences. Sending happens the first time the app is opened or resumed
/// on a new day (phones don't let apps send e-mail in the background).
class EmailBackupConfig {
  const EmailBackupConfig({
    this.enabled = false,
    this.to = '',
    this.from = '',
    this.hasKey = false,
    this.hasPassword = false,
    this.lastSent,
    this.lastError,
  });
  final bool enabled;
  final String to;

  /// A sender address verified in Brevo.
  final String from;
  final bool hasKey;
  final bool hasPassword;
  final DateTime? lastSent;
  final String? lastError;

  bool get ready => to.contains('@') && from.contains('@') && hasKey && hasPassword;
}

class EmailBackupStore {
  static const _secure = FlutterSecureStorage();
  static const _kKey = 'emailBackup.apiKey';
  static const _kPassword = 'emailBackup.password';
  static const _kEnabled = 'emailBackup.enabled';
  static const _kTo = 'emailBackup.to';
  static const _kFrom = 'emailBackup.from';
  static const _kLast = 'emailBackup.lastSent';
  static const _kError = 'emailBackup.lastError';

  static Future<EmailBackupConfig> load() async {
    final p = await SharedPreferences.getInstance();
    final last = p.getString(_kLast);
    return EmailBackupConfig(
      enabled: p.getBool(_kEnabled) ?? false,
      to: p.getString(_kTo) ?? '',
      from: p.getString(_kFrom) ?? '',
      hasKey: ((await _secure.read(key: _kKey)) ?? '').isNotEmpty,
      hasPassword: ((await _secure.read(key: _kPassword)) ?? '').isNotEmpty,
      lastSent: last == null ? null : DateTime.tryParse(last),
      lastError: p.getString(_kError),
    );
  }

  /// Saves the settings; a null [apiKey] / [password] keeps the stored one.
  static Future<void> save({required bool enabled, required String to, required String from, String? apiKey, String? password}) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, enabled);
    await p.setString(_kTo, to.trim());
    await p.setString(_kFrom, from.trim());
    if (apiKey != null && apiKey.trim().isNotEmpty) await _secure.write(key: _kKey, value: apiKey.trim());
    if (password != null && password.isNotEmpty) await _secure.write(key: _kPassword, value: password);
  }

  static Future<void> clearSecrets() async {
    await _secure.delete(key: _kKey);
    await _secure.delete(key: _kPassword);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, false);
  }

  static Future<void> _result(DateTime? sent, String? error) async {
    final p = await SharedPreferences.getInstance();
    if (sent != null) await p.setString(_kLast, sent.toIso8601String());
    if (error == null) {
      await p.remove(_kError);
    } else {
      await p.setString(_kError, error);
    }
  }
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Sends today's backup if it is due (or now with [force]). Returns null on success or when
/// nothing was due, otherwise an error code (`notReady`, `http_<status>`, `network`).
Future<String?> sendEmailBackup(AppDatabase db, {bool force = false, http.Client? client}) async {
  final cfg = await EmailBackupStore.load();
  if (!force && (!cfg.enabled || (cfg.lastSent != null && _sameDay(cfg.lastSent!, DateTime.now())))) return null;
  if (!cfg.ready) return 'notReady';
  final key = await EmailBackupStore._secure.read(key: EmailBackupStore._kKey);
  final password = await EmailBackupStore._secure.read(key: EmailBackupStore._kPassword);
  if (key == null || password == null) return 'notReady';

  final now = DateTime.now();
  final stamp =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  final file = await BackupService(db).export(password);
  final c = client ?? http.Client();
  try {
    final res = await c.post(
      Uri.parse('https://api.brevo.com/v3/smtp/email'),
      headers: {'api-key': key, 'content-type': 'application/json', 'accept': 'application/json'},
      body: jsonEncode({
        'sender': {'email': cfg.from, 'name': 'مصروفي'},
        'to': [
          {'email': cfg.to},
        ],
        'subject': 'نسخة احتياطية من مصروفي – $stamp',
        'htmlContent':
            '<div dir="rtl" style="font-family:sans-serif">'
            '<p>دي النسخة الاحتياطية اليومية من تطبيق مصروفي.</p>'
            '<p>الملف مشفّر بالباسورد اللي اخترته. عشان ترجّعه: الإعدادات ← النسخ الاحتياطي ← استرجاع.</p></div>',
        'attachment': [
          {'name': 'Masarefy_backup_$stamp.masarefy', 'content': base64Encode(utf8.encode(file))},
        ],
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await EmailBackupStore._result(now, null);
      return null;
    }
    final err = 'http_${res.statusCode}';
    await EmailBackupStore._result(null, err);
    return err;
  } catch (_) {
    await EmailBackupStore._result(null, 'network');
    return 'network';
  } finally {
    if (client == null) c.close();
  }
}

/// Runs the daily backup at start-up and whenever the app comes back to the foreground.
final emailBackupProvider = Provider<void>((ref) {
  final db = ref.watch(databaseProvider);
  var running = false;
  Future<void> run() async {
    if (running) return;
    running = true;
    try {
      await sendEmailBackup(db);
    } finally {
      running = false;
    }
  }

  final observer = _ResumeObserver(run);
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
  Future<void>.delayed(const Duration(seconds: 5), run);
});

class _ResumeObserver extends WidgetsBindingObserver {
  _ResumeObserver(this.onResume);
  final Future<void> Function() onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}
