import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/instance_config.dart';
import '../../services/download/aria2_client.dart';
import '../../services/storage/instance_repository.dart';

final _aria2ClientProvider =
    FutureProvider.family<Aria2Client, InstanceConfig>((ref, instance) async {
  final repo = InstanceRepository();
  final secret = await repo.getApiKey(instance.id);
  return Aria2Client(
    baseUrl: instance.baseUrl,
    rpcSecret: (secret == null || secret.isEmpty) ? null : secret,
  );
});

final _aria2DownloadsProvider =
    FutureProvider.family<List<dynamic>, InstanceConfig>((ref, instance) async {
  final client = await ref.watch(_aria2ClientProvider(instance).future);
  final active = await client.getActiveDownloads();
  final waiting = await client.getWaitingDownloads();
  return [...active, ...waiting];
});

/// Aria2 queue: pause/resume/remove by GID, driven through Aria2Client's
/// JSON-RPC calls — same primitives as the AriaNg web UI.
class Aria2DownloadsScreen extends ConsumerWidget {
  final InstanceConfig instance;

  const Aria2DownloadsScreen({super.key, required this.instance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsync = ref.watch(_aria2DownloadsProvider(instance));

    return Scaffold(
      appBar: AppBar(title: Text(instance.label)),
      body: downloadsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (downloads) {
          if (downloads.isEmpty) {
            return const Center(child: Text('No active downloads'));
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(_aria2DownloadsProvider(instance)),
            child: ListView.builder(
              itemCount: downloads.length,
              itemBuilder: (context, index) {
                final d = downloads[index] as Map<String, dynamic>;
                final gid = d['gid'] as String;
                final status = d['status'] as String? ?? '';
                final total =
                    double.tryParse(d['totalLength'] as String? ?? '0') ?? 0;
                final completed =
                    double.tryParse(d['completedLength'] as String? ?? '0') ??
                        0;
                final progress = total > 0 ? completed / total : 0.0;
                final files = d['files'] as List<dynamic>?;
                final name = files != null && files.isNotEmpty
                    ? (files.first['path'] as String? ?? gid)
                        .split(RegExp(r'[\\/]'))
                        .last
                    : gid;

                return ListTile(
                  title:
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 4),
                      Text('${(progress * 100).toStringAsFixed(1)}% · $status'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(status == 'paused'
                            ? Icons.play_arrow
                            : Icons.pause),
                        onPressed: () async {
                          final client = await ref
                              .read(_aria2ClientProvider(instance).future);
                          if (status == 'paused') {
                            await client.unpause(gid);
                          } else {
                            await client.pause(gid);
                          }
                          ref.invalidate(_aria2DownloadsProvider(instance));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final client = await ref
                              .read(_aria2ClientProvider(instance).future);
                          await client.remove(gid);
                          ref.invalidate(_aria2DownloadsProvider(instance));
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
