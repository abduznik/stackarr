import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/instance_config.dart';
import '../../services/download/qbittorrent_client.dart';
import '../../services/storage/instance_repository.dart';
import '../shared/library_search_bar.dart';

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
/// UI's torrent list, driven through QbittorrentClient's cookie-session
/// API, plus a Transfer tab showing global speed and letting the user set
/// download/upload limits — the same controls qBt's own status bar and
/// speed-limit dialog expose.
class DownloadsScreen extends ConsumerStatefulWidget {
  final InstanceConfig instance;

  const DownloadsScreen({super.key, required this.instance});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  String _query = '';

  InstanceConfig get instance => widget.instance;

  @override
  Widget build(BuildContext context) {
    final torrentsAsync = ref.watch(_torrentsProvider(instance));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(instance.label),
          actions: [
            LibrarySearchBar(
              hintText: 'Search torrents...',
              onQueryChanged: (q) => setState(() => _query = q),
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Torrents'),
            Tab(text: 'Transfer'),
          ]),
        ),
        body: TabBarView(
          children: [
            _buildTorrentsList(context, ref, torrentsAsync),
            _TransferTab(instance: instance),
          ],
        ),
      ),
    );
  }

  Widget _buildTorrentsList(BuildContext context, WidgetRef ref,
      AsyncValue<List<dynamic>> torrentsAsync) {
    return torrentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (torrents) {
          if (torrents.isEmpty) {
            return const Center(child: Text('No active downloads'));
          }
          final filtered = filterByTitle(torrents, _query,
              (t) => (t as Map<String, dynamic>)['name'] as String? ?? '');
          if (filtered.isEmpty) {
            return const Center(child: Text('No matches'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_torrentsProvider(instance)),
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final t = filtered[index] as Map<String, dynamic>;
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
        });
  }
}

final _transferInfoProvider =
    FutureProvider.family<Map<String, dynamic>, InstanceConfig>(
        (ref, instance) async {
  final client = await ref.watch(_qbtClientProvider(instance).future);
  return client.getTransferInfo();
});

class _TransferTab extends ConsumerStatefulWidget {
  final InstanceConfig instance;

  const _TransferTab({required this.instance});

  @override
  ConsumerState<_TransferTab> createState() => _TransferTabState();
}

class _TransferTabState extends ConsumerState<_TransferTab> {
  final _downloadController = TextEditingController();
  final _uploadController = TextEditingController();

  @override
  void dispose() {
    _downloadController.dispose();
    _uploadController.dispose();
    super.dispose();
  }

  Future<void> _applyLimits() async {
    final client = await ref.read(_qbtClientProvider(widget.instance).future);
    final downloadKbps = int.tryParse(_downloadController.text);
    final uploadKbps = int.tryParse(_uploadController.text);
    await client.setSpeedLimit(
      downloadKbps: downloadKbps == 0 ? null : downloadKbps,
      uploadKbps: uploadKbps == 0 ? null : uploadKbps,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speed limits updated')),
      );
    }
    ref.invalidate(_transferInfoProvider(widget.instance));
  }

  String _formatBytesPerSec(num? bytes) {
    if (bytes == null || bytes == 0) return '0 B/s';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB/s';
    return '${(kb / 1024).toStringAsFixed(1)} MB/s';
  }

  @override
  Widget build(BuildContext context) {
    final transferAsync = ref.watch(_transferInfoProvider(widget.instance));

    return transferAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (info) {
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(_transferInfoProvider(widget.instance)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Download speed'),
                trailing:
                    Text(_formatBytesPerSec(info['dl_info_speed'] as num?)),
              ),
              ListTile(
                leading: const Icon(Icons.upload),
                title: const Text('Upload speed'),
                trailing:
                    Text(_formatBytesPerSec(info['up_info_speed'] as num?)),
              ),
              const Divider(height: 32),
              Text('Speed limits (KB/s, 0 = unlimited)',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              TextField(
                controller: _downloadController,
                decoration: const InputDecoration(labelText: 'Download limit'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _uploadController,
                decoration: const InputDecoration(labelText: 'Upload limit'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _applyLimits,
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
  }
}
