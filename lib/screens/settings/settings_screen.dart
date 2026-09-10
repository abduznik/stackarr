import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/instance_config.dart';
import '../../providers/instance_providers.dart';
import '../../services/storage/app_lock_repository.dart';
import '../../services/storage/biometric_auth_service.dart';
import '../lock/set_pin_screen.dart';
import '../setup/setup_wizard_screen.dart';

/// Lists every configured instance with a remove action, a button to
/// launch the same wizard flow used on first run to add more services,
/// and a Security section to enable/disable the app-level PIN/biometric
/// lock (see lib/screens/lock).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _lockRepo = AppLockRepository();
  final _biometrics = BiometricAuthService();

  Future<void> _toggleLock(bool enable) async {
    if (enable) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const SetPinScreen()),
      );
      if (result == true && mounted) setState(() {});
    } else {
      await _lockRepo.disableLock();
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (enable) {
      final available = await _biometrics.isAvailable();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Biometric auth is not available on this device')),
          );
        }
        return;
      }
    }
    await _lockRepo.setBiometricEnabled(enable);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final instancesAsync = ref.watch(instancesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: instancesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (instances) => ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Configured services',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final instance in instances) _InstanceTile(instance: instance),
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add another service'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const SetupWizardScreen(isFirstRun: false),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Security',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            FutureBuilder<bool>(
              future: _lockRepo.isLockEnabled(),
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? false;
                return SwitchListTile(
                  title: const Text('App lock'),
                  subtitle: const Text('Require a PIN to open Stackarr'),
                  value: enabled,
                  onChanged: _toggleLock,
                );
              },
            ),
            FutureBuilder<bool>(
              future: _lockRepo.isLockEnabled(),
              builder: (context, lockSnapshot) {
                if (lockSnapshot.data != true) return const SizedBox.shrink();
                return FutureBuilder<bool>(
                  future: _lockRepo.isBiometricEnabled(),
                  builder: (context, snapshot) {
                    final enabled = snapshot.data ?? false;
                    return SwitchListTile(
                      title: const Text('Biometric unlock'),
                      subtitle: const Text(
                          'Use fingerprint or face instead of the PIN'),
                      value: enabled,
                      onChanged: _toggleBiometric,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InstanceTile extends ConsumerWidget {
  final InstanceConfig instance;

  const _InstanceTile({required this.instance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(instance.label),
      subtitle: Text('${instance.type.label} · ${instance.baseUrl}'),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Remove ${instance.label}?'),
              content: const Text(
                  'This disconnects the app from this service. It does not '
                  'change anything on the server itself.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Remove'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            final repo = ref.read(instanceRepositoryProvider);
            await repo.remove(instance.id);
            ref.invalidate(instancesProvider);
            ref.invalidate(hasAnyInstanceProvider);
          }
        },
      ),
    );
  }
}
