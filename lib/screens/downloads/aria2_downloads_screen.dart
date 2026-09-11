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

final _aria2StoppedProvider =
    FutureProvider.family<List<dynamic>, InstanceConfig>((ref, instance) async {
  final client = await ref.watch(_aria2ClientProvider(instance).future);
  return client.getStoppedDownloads();
});

/// Aria2 queue: pause/resume/remove by GID, driven through Aria2Client's
/// JSON-RPC calls — same primitives as the AriaNg web UI — plus a
/// History tab (aria2's tellStopped) for completed/errored/removed
/// downloads, since Active alone couldn't show anything that finished.
class Aria2DownloadsScreen extends ConsumerWidget {
  final InstanceConfig instance;

  const Aria2DownloadsScreen({super.key, required this.instance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(instance.label),
          bottom: const TabBar(tabs: [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ]),
        ),
        body: TabBarView(
          children: [
            _ActiveTab(instance: instance),
            _HistoryTab(instance: instance),
          ],
        ),
      ),
    );
  }
}

class _ActiveTab extends ConsumerWidget {
  final InstanceConfig instance;

  const _ActiveTab({required this.instance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsync = ref.watch(_aria2DownloadsProvider(instance));

    return downloadsAsync.when(
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
            itemBuilder: (context, index) => _Aria2Tile(
              download: downloads[index] as Map<String, dynamic>,
              trailing: _ActiveActions(
                download: downloads[index] as Map<String, dynamic>,
                instance: instance,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActiveActions extends ConsumerWidget {
  final Map<String, dynamic> download;
  final InstanceConfig instance;

  const _ActiveActions({required this.download, required this.instance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gid = download['gid'] as String;
    final status = download['status'] as String? ?? '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(status == 'paused' ? Icons.play_arrow : Icons.pause),
          onPressed: () async {
            final client =
                await ref.read(_aria2ClientProvider(instance).future);
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
            final client =
                await ref.read(_aria2ClientProvider(instance).future);
            await client.remove(gid);
            ref.invalidate(_aria2DownloadsProvider(instance));
          },
        ),
      ],
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  final InstanceConfig instance;

  const _HistoryTab({required this.instance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stoppedAsync = ref.watch(_aria2StoppedProvider(instance));

    return stoppedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (downloads) {
        if (downloads.isEmpty) {
          return const Center(child: Text('No download history'));
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(_aria2StoppedProvider(instance)),
          child: ListView.builder(
            itemCount: downloads.length,
            itemBuilder: (context, index) {
              final download = downloads[index] as Map<String, dynamic>;
              final status = download['status'] as String? ?? '';
              return _Aria2Tile(
                download: download,
                trailing: Icon(
                  status == 'complete' ? Icons.check_circle : Icons.error,
                  color: status == 'complete' ? Colors.green : Colors.red,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Shared row rendering for both tabs — name/progress/status line are
/// identical, only the trailing action differs (pause/resume/remove for
/// Active, a status icon for History).
class _Aria2Tile extends StatelessWidget {
  final Map<String, dynamic> download;
  final Widget trailing;

  const _Aria2Tile({required this.download, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final status = download['status'] as String? ?? '';
    final total =
        double.tryParse(download['totalLength'] as String? ?? '0') ?? 0;
    final completed =
        double.tryParse(download['completedLength'] as String? ?? '0') ?? 0;
    final progress = total > 0 ? completed / total : 0.0;
    final files = download['files'] as List<dynamic>?;
    final gid = download['gid'] as String;
    final name = files != null && files.isNotEmpty
        ? (files.first['path'] as String? ?? gid).split(RegExp(r'[\\/]')).last
        : gid;

    return ListTile(
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 4),
          Text('${(progress * 100).toStringAsFixed(1)}% · $status'),
        ],
      ),
      trailing: trailing,
    );
  }
}
