import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Persists whether an app-level lock is enabled and its PIN hash.
/// Biometric auth (via local_auth) is offered as a faster unlock *in
/// addition to* the PIN when the platform supports it, but the PIN is
/// the universal fallback — local_auth has no web implementation, and
/// a user's device may not have biometrics enrolled.
///
/// The PIN itself is never stored in plaintext, only a SHA-256 hash, so
/// reading secure storage's contents directly can't recover it.
class AppLockRepository {
  static const _pinHashKey = 'stackarr.app_lock.pin_hash';
  static const _biometricEnabledKey = 'stackarr.app_lock.biometric_enabled';

  final FlutterSecureStorage _secureStorage;

  AppLockRepository({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  String _hash(String pin) => sha256.convert(utf8.encode(pin)).toString();

  Future<bool> isLockEnabled() async {
    final hash = await _secureStorage.read(key: _pinHashKey);
    return hash != null;
  }

  Future<void> setPin(String pin) async {
    await _secureStorage.write(key: _pinHashKey, value: _hash(pin));
  }

  Future<bool> verifyPin(String pin) async {
    final storedHash = await _secureStorage.read(key: _pinHashKey);
    if (storedHash == null) return false;
    return storedHash == _hash(pin);
  }

  Future<void> disableLock() async {
    await _secureStorage.delete(key: _pinHashKey);
    await _secureStorage.delete(key: _biometricEnabledKey);
  }

  Future<bool> isBiometricEnabled() async {
    final value = await _secureStorage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _secureStorage.write(
        key: _biometricEnabledKey, value: enabled.toString());
  }
}
