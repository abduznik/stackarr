import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/instance_config.dart';
import '../../models/service_type.dart';
import '../../providers/instance_providers.dart';
import 'add_instance_screen.dart';

/// First-run flow: pick which *arr/download/request services to connect,
/// walk through each one's connection form, then hand off to the app shell.
/// Also reachable from Settings as "Add another service" — [isFirstRun]
/// only changes the finish button's label and destination.
class SetupWizardScreen extends ConsumerStatefulWidget {
  final bool isFirstRun;
  final VoidCallback? onFinished;

  const SetupWizardScreen({
    super.key,
    this.isFirstRun = true,
    this.onFinished,
  });

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  final Set<ServiceType> _connected = {};

  Future<void> _connectService(ServiceType type) async {
    final result = await Navigator.of(context).push<InstanceConfig>(
      MaterialPageRoute(
        builder: (_) => AddInstanceScreen(serviceType: type),
      ),
    );
    if (result != null) {
      setState(() => _connected.add(type));
    }
  }

  @override
  Widget build(BuildContext context) {
    final coreServices = [
      ServiceType.radarr,
      ServiceType.sonarr,
      ServiceType.lidarr,
    ];
    final optionalServices = [
      ServiceType.prowlarr,
      ServiceType.bazarr,
      ServiceType.qbittorrent,
      ServiceType.aria2,
      ServiceType.jellyseerr,
    ];

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.isFirstRun ? 'Welcome to Stackarr' : 'Add a service'),
        automaticallyImplyLeading: !widget.isFirstRun,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.isFirstRun)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Connect the services in your media stack. You can add or '
                'remove services anytime from Settings.',
              ),
            ),
          Text('Core library services',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...coreServices.map(_buildServiceTile),
          const SizedBox(height: 24),
          Text('Optional services',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...optionalServices.map(_buildServiceTile),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _connected.isEmpty
                ? null
                : () {
                    ref.invalidate(instancesProvider);
                    ref.invalidate(hasAnyInstanceProvider);
                    if (widget.onFinished != null) {
                      widget.onFinished!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
            child: Text(widget.isFirstRun
                ? 'Finish setup (${_connected.length} connected)'
                : 'Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTile(ServiceType type) {
    final connected = _connected.contains(type);
    return Card(
      child: ListTile(
        leading: Icon(_iconFor(type)),
        title: Text(type.label),
        subtitle: Text(type.description),
        trailing: connected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.chevron_right),
        onTap: () => _connectService(type),
      ),
    );
  }

  IconData _iconFor(ServiceType type) => switch (type) {
        ServiceType.radarr => Icons.movie_outlined,
        ServiceType.sonarr => Icons.tv_outlined,
        ServiceType.lidarr => Icons.music_note_outlined,
        ServiceType.prowlarr => Icons.search,
        ServiceType.bazarr => Icons.subtitles_outlined,
        ServiceType.qbittorrent => Icons.download_outlined,
        ServiceType.aria2 => Icons.downloading_outlined,
        ServiceType.jellyseerr => Icons.inbox_outlined,
      };
}
