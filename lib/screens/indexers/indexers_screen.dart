import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/indexer.dart';
import '../../models/instance_config.dart';
import '../../services/arr/prowlarr_client.dart';
import '../../services/storage/instance_repository.dart';
import '../shared/library_search_bar.dart';

final _prowlarrClientProvider =
    FutureProvider.family<ProwlarrClient, InstanceConfig>(
        (ref, instance) async {
  final repo = InstanceRepository();
  final apiKey = await repo.getApiKey(instance.id);
  return ProwlarrClient(baseUrl: instance.baseUrl, apiKey: apiKey ?? '');
});

final _indexersProvider =
    FutureProvider.family<List<Indexer>, InstanceConfig>((ref, instance) async {
  final client = await ref.watch(_prowlarrClientProvider(instance).future);
  return client.getIndexers();
});

/// Prowlarr indexer management: enable/disable, test, and sync to
/// connected apps — the same actions available in Prowlarr's web UI —
/// plus an Applications tab showing which Radarr/Sonarr/Lidarr instances
/// Prowlarr pushes indexers to, mirroring Prowlarr's own Settings >
/// Apps page.
class IndexersScreen extends ConsumerStatefulWidget {
  final InstanceConfig instance;

  const IndexersScreen({super.key, required this.instance});

  @override
  ConsumerState<IndexersScreen> createState() => _IndexersScreenState();
}

class _IndexersScreenState extends ConsumerState<IndexersScreen> {
  String _query = '';

  InstanceConfig get instance => widget.instance;

  @override
  Widget build(BuildContext context) {
    final indexersAsync = ref.watch(_indexersProvider(instance));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(instance.label),
          actions: [
            LibrarySearchBar(
              hintText: 'Search indexers...',
              onQueryChanged: (q) => setState(() => _query = q),
            ),
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sync all indexers to apps',
              onPressed: () async {
                final client =
                    await ref.read(_prowlarrClientProvider(instance).future);
                await client.syncAllIndexers();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sync triggered')),
                  );
                }
              },
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Indexers'),
            Tab(text: 'Applications'),
          ]),
        ),
        body: TabBarView(
          children: [
            indexersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (indexers) {
                if (indexers.isEmpty) {
                  return const Center(child: Text('No indexers configured'));
                }
                final filtered = filterByTitle(indexers, _query, (i) => i.name);
                if (filtered.isEmpty) {
                  return const Center(child: Text('No matches'));
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(_indexersProvider(instance)),
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final indexer = filtered[index];
                      return ListTile(
                        leading: Icon(indexer.protocol == 'torrent'
                            ? Icons.swap_vert
                            : Icons.forum_outlined),
                        title: Text(indexer.name),
                        subtitle: Text(
                            '${indexer.protocol} · priority ${indexer.priority}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.wifi_tethering),
                              tooltip: 'Test',
                              onPressed: () async {
                                final client = await ref.read(
                                    _prowlarrClientProvider(instance).future);
                                final ok = await client.testIndexer(indexer.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(ok
                                            ? '${indexer.name}: OK'
                                            : '${indexer.name}: failed')),
                                  );
                                }
                              },
                            ),
                            Switch(
                              value: indexer.enable,
                              onChanged: (value) async {
                                final client = await ref.read(
                                    _prowlarrClientProvider(instance).future);
                                await client.setIndexerEnabled(
                                    indexer.id, value);
                                ref.invalidate(_indexersProvider(instance));
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            _ApplicationsTab(instance: instance),
          ],
        ),
      ),
    );
  }
}

final _applicationsProvider =
    FutureProvider.family<List<dynamic>, InstanceConfig>((ref, instance) async {
  final client = await ref.watch(_prowlarrClientProvider(instance).future);
  return client.getApplications();
});

class _ApplicationsTab extends ConsumerWidget {
  final InstanceConfig instance;

  const _ApplicationsTab({required this.instance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(_applicationsProvider(instance));

    return appsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (apps) {
        if (apps.isEmpty) {
          return const Center(child: Text('No connected applications'));
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(_applicationsProvider(instance)),
          child: ListView.builder(
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index] as Map<String, dynamic>;
              final syncLevel = app['syncLevel'] as String? ?? 'unknown';
              return ListTile(
                leading: const Icon(Icons.link),
                title: Text(app['name'] as String? ?? 'Unknown'),
                subtitle: Text(
                    '${app['implementationName'] as String? ?? ''} · sync: $syncLevel'),
              );
            },
          ),
        );
      },
    );
  }
}
