import 'package:flutter/material.dart';
import '../../services/storage/app_lock_repository.dart';
import '../../services/storage/biometric_auth_service.dart';

/// Shown at launch when an app lock is configured. Tries biometric
/// unlock automatically if enabled and available, otherwise (or on
/// biometric failure/cancel) falls back to PIN entry — the PIN is
/// always the universal path since biometrics aren't guaranteed to be
/// available on every platform/device.
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _repo = AppLockRepository();
  final _biometrics = BiometricAuthService();
  final _pinController = TextEditingController();
  String? _error;
  bool _checkingBiometric = true;

  @override
  void initState() {
    super.initState();
    _tryBiometricUnlock();
  }

  Future<void> _tryBiometricUnlock() async {
    final enabled = await _repo.isBiometricEnabled();
    final available = enabled && await _biometrics.isAvailable();
    if (available) {
      final ok = await _biometrics.authenticate();
      if (ok) {
        widget.onUnlocked();
        return;
      }
    }
    if (mounted) setState(() => _checkingBiometric = false);
  }

  Future<void> _submitPin() async {
    final ok = await _repo.verifyPin(_pinController.text);
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() => _error = 'Incorrect PIN');
      _pinController.clear();
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingBiometric) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                Text('Enter PIN',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinController,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 8,
                  decoration: InputDecoration(
                    errorText: _error,
                    counterText: '',
                  ),
                  onSubmitted: (_) => _submitPin(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submitPin,
                  child: const Text('Unlock'),
                ),
                FutureBuilder<bool>(
                  future: () async {
                    final enabled = await _repo.isBiometricEnabled();
                    return enabled && await _biometrics.isAvailable();
                  }(),
                  builder: (context, snapshot) {
                    if (snapshot.data != true) return const SizedBox.shrink();
                    return TextButton.icon(
                      onPressed: _tryBiometricUnlock,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Use biometrics'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
