import 'package:flutter/material.dart';
import '../../services/storage/app_lock_repository.dart';
import '../../services/storage/biometric_auth_service.dart';

/// Two-step PIN entry (enter, then confirm) shown from Settings when
/// turning app lock on. Offers to also enable biometric unlock as a
/// shortcut once the PIN is set, if the platform supports it.
class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final _repo = AppLockRepository();
  final _biometrics = BiometricAuthService();
  final _firstController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _firstPin;
  String? _error;

  Future<void> _onFirstSubmitted() async {
    if (_firstController.text.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits');
      return;
    }
    setState(() {
      _firstPin = _firstController.text;
      _error = null;
    });
  }

  Future<void> _onConfirmSubmitted() async {
    if (_confirmController.text != _firstPin) {
      setState(() {
        _error = 'PINs did not match';
        _firstPin = null;
        _firstController.clear();
        _confirmController.clear();
      });
      return;
    }

    await _repo.setPin(_firstPin!);

    if (!mounted) return;
    final biometricAvailable = await _biometrics.isAvailable();
    if (biometricAvailable && mounted) {
      final enableBiometric = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enable biometric unlock?'),
          content: const Text(
              'You can also unlock with your fingerprint or face instead of typing the PIN.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No thanks'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Enable'),
            ),
          ],
        ),
      );
      if (enableBiometric == true) {
        await _repo.setBiometricEnabled(true);
      }
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _firstController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmStep = _firstPin != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Set App PIN')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isConfirmStep ? 'Confirm PIN' : 'Choose a PIN',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                TextField(
                  key: ValueKey(isConfirmStep),
                  controller:
                      isConfirmStep ? _confirmController : _firstController,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 8,
                  decoration: InputDecoration(
                    errorText: _error,
                    counterText: '',
                  ),
                  onSubmitted: (_) => isConfirmStep
                      ? _onConfirmSubmitted()
                      : _onFirstSubmitted(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed:
                      isConfirmStep ? _onConfirmSubmitted : _onFirstSubmitted,
                  child: Text(isConfirmStep ? 'Confirm' : 'Next'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
