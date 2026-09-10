import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Thin wrapper around local_auth that fails closed (returns false)
/// rather than throwing on platforms/devices without biometric support —
/// there's no local_auth web implementation, and desktop/older devices
/// may have no enrolled biometrics, so every call site should treat
/// "unavailable" as "fall back to the PIN" rather than an error.
class BiometricAuthService {
  final LocalAuthentication _auth;

  BiometricAuthService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Stackarr',
        biometricOnly: false,
      );
    } catch (_) {
      return false;
    }
  }
}
