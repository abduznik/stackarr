import 'package:flutter_test/flutter_test.dart';
import 'package:stackarr/services/storage/app_lock_repository.dart';
import '../test_helpers/secure_storage_mock.dart';

void main() {
  setUp(() {
    mockSecureStorage();
  });

  test('lock is disabled by default', () async {
    final repo = AppLockRepository();
    expect(await repo.isLockEnabled(), isFalse);
  });

  test('setting a PIN enables the lock', () async {
    final repo = AppLockRepository();
    await repo.setPin('1234');
    expect(await repo.isLockEnabled(), isTrue);
  });

  test('verifyPin returns true for the correct PIN', () async {
    final repo = AppLockRepository();
    await repo.setPin('1234');
    expect(await repo.verifyPin('1234'), isTrue);
  });

  test('verifyPin returns false for an incorrect PIN', () async {
    final repo = AppLockRepository();
    await repo.setPin('1234');
    expect(await repo.verifyPin('0000'), isFalse);
  });

  test('verifyPin returns false when no PIN has been set', () async {
    final repo = AppLockRepository();
    expect(await repo.verifyPin('1234'), isFalse);
  });

  test('disableLock clears the PIN and biometric flag', () async {
    final repo = AppLockRepository();
    await repo.setPin('1234');
    await repo.setBiometricEnabled(true);

    await repo.disableLock();

    expect(await repo.isLockEnabled(), isFalse);
    expect(await repo.isBiometricEnabled(), isFalse);
  });

  test('biometric is disabled by default', () async {
    final repo = AppLockRepository();
    expect(await repo.isBiometricEnabled(), isFalse);
  });

  test('setBiometricEnabled persists true and false', () async {
    final repo = AppLockRepository();
    await repo.setBiometricEnabled(true);
    expect(await repo.isBiometricEnabled(), isTrue);

    await repo.setBiometricEnabled(false);
    expect(await repo.isBiometricEnabled(), isFalse);
  });
}
