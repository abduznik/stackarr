import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/instance_config.dart';
import '../../providers/instance_providers.dart';
import '../setup/setup_wizard_screen.dart';

/// Lists every configured instance with a remove action, and a button to
/// launch the same wizard flow used on first run to add more services.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
