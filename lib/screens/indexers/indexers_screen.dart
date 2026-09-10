import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/indexer.dart';
import '../../models/instance_config.dart';
import '../../services/arr/prowlarr_client.dart';
import '../../services/storage/instance_repository.dart';

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
/// connected apps — the same actions available in Prowlarr's web UI.
class IndexersScreen extends ConsumerWidget {
  final InstanceConfig instance;

  const IndexersScreen({super.key, required this.instance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indexersAsync = ref.watch(_indexersProvider(instance));

    return Scaffold(
      appBar: AppBar(
        title: Text(instance.label),
        actions: [
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
      ),
      body: indexersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (indexers) {
          if (indexers.isEmpty) {
            return const Center(child: Text('No indexers configured'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_indexersProvider(instance)),
            child: ListView.builder(
              itemCount: indexers.length,
              itemBuilder: (context, index) {
                final indexer = indexers[index];
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
                          final client = await ref
                              .read(_prowlarrClientProvider(instance).future);
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
                          final client = await ref
                              .read(_prowlarrClientProvider(instance).future);
                          await client.setIndexerEnabled(indexer.id, value);
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
    );
  }
}
