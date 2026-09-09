import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps flutter_secure_storage (Keychain on iOS, Keystore-backed EncryptedSharedPreferences
/// on Android) for every secret this app holds: the DB encryption key, the PIN hash+salt, and
/// the biometric-enabled flag. Nothing here is ever stored in plain SharedPreferences.
class SecureStorageService {
  SecureStorageService._();
  static final instance = SecureStorageService._();

  static const _dbKeyKey = 'db-encryption-key';
  static const _pinHashKey = 'app-lock-pin-hash';
  static const _pinSaltKey = 'app-lock-pin-salt';

  // Defaults already use AES-GCM with RSA-OAEP key wrapping on Android (11.x) and Keychain
  // on iOS — no extra options needed (the old `encryptedSharedPreferences` flag is gone).
  final _storage = const FlutterSecureStorage();

  final _pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 120000, bits: 256);

  String _randomHex(int byteLength) {
    final random = Random.secure();
    final bytes = List<int>.generate(byteLength, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// The encryption key is generated once and kept in the OS keychain/keystore — never
  /// derived from the PIN (the PIN gates app *access*; this is a separate DB secret).
  /// Losing it means losing the database; that trade-off is intentional (see NFR on encryption).
  Future<String> getOrCreateDbEncryptionKey() async {
    final existing = await _storage.read(key: _dbKeyKey);
    if (existing != null) return existing;
    final key = _randomHex(32);
    await _storage.write(key: _dbKeyKey, value: key);
    return key;
  }

  Future<bool> hasPinSet() async {
    return (await _storage.read(key: _pinHashKey)) != null;
  }

  Future<void> setPin(String pin) async {
    final salt = _randomHex(16);
    final hash = await _hashPin(pin, salt);
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: hash);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _pinSaltKey);
    final storedHash = await _storage.read(key: _pinHashKey);
    if (salt == null || storedHash == null) return false;
    final candidate = await _hashPin(pin, salt);
    return candidate == storedHash;
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
  }

  Future<String> _hashPin(String pin, String saltHex) async {
    final secretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: utf8.encode(saltHex),
    );
    final bytes = await secretKey.extractBytes();
    return base64Encode(bytes);
  }
}
