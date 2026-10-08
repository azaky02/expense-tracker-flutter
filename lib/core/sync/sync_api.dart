import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../security/secure_storage.dart';

/// Server login kept in the OS keystore (never in plain preferences).
class SyncSession {
  const SyncSession({
    required this.serverUrl,
    required this.userId,
    required this.email,
    required this.name,
    required this.accessToken,
    required this.refreshToken,
  });

  final String serverUrl;
  final String userId;
  final String email;
  final String name;
  final String accessToken;
  final String refreshToken;

  SyncSession withTokens(String access, String refresh) => SyncSession(
        serverUrl: serverUrl,
        userId: userId,
        email: email,
        name: name,
        accessToken: access,
        refreshToken: refresh,
      );

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'userId': userId,
        'email': email,
        'name': name,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };

  factory SyncSession.fromJson(Map<String, dynamic> j) => SyncSession(
        serverUrl: j['serverUrl'] as String,
        userId: j['userId'] as String,
        email: j['email'] as String,
        name: (j['name'] as String?) ?? '',
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
      );

  static Future<SyncSession?> load() async {
    final raw = await SecureStorageService.instance.readSyncSession();
    if (raw == null) return null;
    try {
      return SyncSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save() =>
      SecureStorageService.instance.writeSyncSession(jsonEncode(toJson()));

  static Future<void> clear() => SecureStorageService.instance.clearSyncSession();
}

/// An error answer from the server (`{"error": "<code>"}`) or a transport failure (`network`).
class ApiException implements Exception {
  ApiException(this.status, this.code);
  final int status;
  final String code;
  bool get isNetwork => status == 0;
  @override
  String toString() => 'ApiException($status, $code)';
}

/// Turns what the user typed into a base URL: trims, adds https:// when no scheme was given,
/// drops a trailing slash and any /api suffix.
String normalizeServerUrl(String input) {
  var u = input.trim();
  if (u.isEmpty) return u;
  if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'https://$u';
  while (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  if (u.endsWith('/api')) u = u.substring(0, u.length - 4);
  return u;
}

class SyncApi {
  SyncApi(this.serverUrl, {this._session, this.onSessionChanged, http.Client? client})
      : _client = client ?? http.Client();

  final String serverUrl;
  final void Function(SyncSession)? onSessionChanged;
  final http.Client _client;
  SyncSession? _session;

  Uri _uri(String path) => Uri.parse('$serverUrl/api$path');

  Future<Map<String, dynamic>> _send(String method, String path, Object? body,
      {String? token}) async {
    final req = http.Request(method, _uri(path))
      ..headers['content-type'] = 'application/json'
      ..headers['accept'] = 'application/json';
    if (token != null) req.headers['authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);
    try {
      final res = await http.Response.fromStream(
          await _client.send(req).timeout(const Duration(seconds: 60)));
      Map<String, dynamic> json = const {};
      try {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {/* non-JSON body (e.g. an IIS error page) */}
      if (res.statusCode >= 200 && res.statusCode < 300) return json;
      throw ApiException(res.statusCode, (json['error'] as String?) ?? 'http_${res.statusCode}');
    } on SocketException {
      throw ApiException(0, 'network');
    } on TimeoutException {
      throw ApiException(0, 'network');
    } on http.ClientException {
      throw ApiException(0, 'network');
    } on HandshakeException {
      throw ApiException(0, 'tls');
    }
  }

  SyncSession _sessionFrom(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>;
    return SyncSession(
      serverUrl: serverUrl,
      userId: user['id'] as String,
      email: user['email'] as String,
      name: (user['name'] as String?) ?? '',
      accessToken: j['accessToken'] as String,
      refreshToken: j['refreshToken'] as String,
    );
  }

  Future<SyncSession> login(String email, String password) async {
    final s = _sessionFrom(await _send('POST', '/auth/login', {'email': email, 'password': password}));
    _session = s;
    return s;
  }

  Future<SyncSession> register(String email, String password, String name, String? signupCode) async {
    final s = _sessionFrom(await _send('POST', '/auth/register', {
      'email': email,
      'password': password,
      'name': name,
      if (signupCode != null && signupCode.isNotEmpty) 'signupCode': signupCode,
    }));
    _session = s;
    return s;
  }

  Future<void> logout() async {
    final s = _session;
    if (s == null) return;
    try {
      await _send('POST', '/auth/logout', {'refreshToken': s.refreshToken});
    } on ApiException {/* best effort */}
  }

  Future<void> deleteAccount(String password) =>
      _authed('DELETE', '/me', {'password': password});

  Future<Map<String, dynamic>> sync(Map<String, dynamic> body) => _authed('POST', '/sync', body);

  /// Calls an authenticated endpoint; on 401 refreshes the tokens once and retries.
  Future<Map<String, dynamic>> _authed(String method, String path, Object? body) async {
    final s = _session;
    if (s == null) throw ApiException(401, 'unauthorized');
    try {
      return await _send(method, path, body, token: s.accessToken);
    } on ApiException catch (e) {
      if (e.status != 401) rethrow;
    }
    final refreshed = _sessionFrom(await _send('POST', '/auth/refresh', {'refreshToken': s.refreshToken}));
    _session = refreshed;
    onSessionChanged?.call(refreshed);
    return _send(method, path, body, token: refreshed.accessToken);
  }

  void close() => _client.close();
}
