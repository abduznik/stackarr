import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/instance_config.dart';
import '../../models/service_type.dart';
import '../../providers/instance_providers.dart';
import '../settings/settings_screen.dart';
import 'dashboard_screen.dart';
import 'service_screen_router.dart';

/// The main app shell shown once at least one service is configured.
/// Uses NavigationRail on wide/landscape layouts (desktop, tablet landscape)
/// and NavigationBar (bottom nav) on narrow/portrait layouts (phone) — the
/// breakpoint follows Material 3 guidance (600dp).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final instancesAsync = ref.watch(instancesProvider);

    return instancesAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (instances) {
        final destinations = _buildDestinations(instances);
        final isWide = MediaQuery.sizeOf(context).width >= 600;
        final safeIndex =
            _selectedIndex < destinations.length ? _selectedIndex : 0;

        final body = destinations.isEmpty
            ? const Center(child: Text('No services configured'))
            : destinations[safeIndex].builder(context);

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: safeIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _selectedIndex = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            destinations: [
              for (final d in destinations)
                NavigationDestination(icon: Icon(d.icon), label: d.label),
            ],
          ),
        );
      },
    );
  }

  List<_Destination> _buildDestinations(List<InstanceConfig> instances) {
    final destinations = <_Destination>[
      _Destination(
        label: 'Home',
        icon: Icons.dashboard_outlined,
        builder: (_) => const DashboardScreen(),
      ),
    ];

    for (final instance in instances) {
      destinations.add(_Destination(
        label: instance.label,
        icon: _iconForType(instance.type),
        builder: (_) => ServiceScreenRouter(instance: instance),
      ));
    }

    destinations.add(_Destination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      builder: (_) => const SettingsScreen(),
    ));

    return destinations;
  }

  IconData _iconForType(ServiceType type) => switch (type) {
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

class _Destination {
  final String label;
  final IconData icon;
  final WidgetBuilder builder;

  const _Destination(
      {required this.label, required this.icon, required this.builder});
}
