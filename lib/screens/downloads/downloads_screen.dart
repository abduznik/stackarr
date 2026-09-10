import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/instance_config.dart';
import '../../services/download/qbittorrent_client.dart';
import '../../services/storage/instance_repository.dart';

final _qbtClientProvider =
    FutureProvider.family<QbittorrentClient, InstanceConfig>(
        (ref, instance) async {
  final repo = InstanceRepository();
  final secret = await repo.getApiKey(instance.id) ?? ':';
  final parts = secret.split(':');
  final client = QbittorrentClient(
    baseUrl: instance.baseUrl,
    username: parts.isNotEmpty ? parts[0] : '',
    password: parts.length > 1 ? parts.sublist(1).join(':') : '',
  );
  await client.login();
  return client;
});

final _torrentsProvider =
    FutureProvider.family<List<dynamic>, InstanceConfig>((ref, instance) async {
  final client = await ref.watch(_qbtClientProvider(instance).future);
  return client.getTorrents();
});

/// qBittorrent queue: pause/resume/delete, same primitives as the qBt Web
/// UI's torrent list, driven through QbittorrentClient's cookie-session API.
class DownloadsScreen extends ConsumerWidget {
  final InstanceConfig instance;

  const DownloadsScreen({super.key, required this.instance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final torrentsAsync = ref.watch(_torrentsProvider(instance));

    return Scaffold(
      appBar: AppBar(title: Text(instance.label)),
      body: torrentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (torrents) {
          if (torrents.isEmpty) {
            return const Center(child: Text('No active downloads'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_torrentsProvider(instance)),
            child: ListView.builder(
              itemCount: torrents.length,
              itemBuilder: (context, index) {
                final t = torrents[index] as Map<String, dynamic>;
                final progress = (t['progress'] as num?)?.toDouble() ?? 0;
                final state = t['state'] as String? ?? '';
                final paused = state.contains('paused');
                final hash = t['hash'] as String;

                return ListTile(
                  title: Text(t['name'] as String? ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 4),
                      Text('${(progress * 100).toStringAsFixed(1)}% · $state'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                        onPressed: () async {
                          final client = await ref
                              .read(_qbtClientProvider(instance).future);
                          if (paused) {
                            await client.resumeTorrents([hash]);
                          } else {
                            await client.pauseTorrents([hash]);
                          }
                          ref.invalidate(_torrentsProvider(instance));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Remove torrent?'),
                              content: const Text(
                                  'This removes the torrent from the queue.'),
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
                            final client = await ref
                                .read(_qbtClientProvider(instance).future);
                            await client.deleteTorrents([hash]);
                            ref.invalidate(_torrentsProvider(instance));
                          }
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
