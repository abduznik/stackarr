import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/instance_config.dart';
import '../../services/download/aria2_client.dart';
import '../../services/storage/instance_repository.dart';
import '../shared/library_search_bar.dart';

/// Aria2 doesn't return a plain "name" field — the display name has to
/// be derived from the first file's path (or fall back to the gid).
/// Pulled out so both the row display and the search filter use the
/// exact same derivation.
String aria2DisplayName(Map<String, dynamic> download) {
  final gid = download['gid'] as String;
  final files = download['files'] as List<dynamic>?;
  if (files == null || files.isEmpty) return gid;
  final path = files.first['path'] as String? ?? gid;
  return path.split(RegExp(r'[\\/]')).last;
}

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
class Aria2DownloadsScreen extends ConsumerStatefulWidget {
  final InstanceConfig instance;

  const Aria2DownloadsScreen({super.key, required this.instance});

  @override
  ConsumerState<Aria2DownloadsScreen> createState() =>
      _Aria2DownloadsScreenState();
}

class _Aria2DownloadsScreenState extends ConsumerState<Aria2DownloadsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.instance.label),
          actions: [
            LibrarySearchBar(
              hintText: 'Search downloads...',
              onQueryChanged: (q) => setState(() => _query = q),
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ]),
        ),
        body: TabBarView(
          children: [
            _ActiveTab(instance: widget.instance, query: _query),
            _HistoryTab(instance: widget.instance, query: _query),
          ],
        ),
      ),
    );
  }
}

class _ActiveTab extends ConsumerWidget {
  final InstanceConfig instance;
  final String query;

  const _ActiveTab({required this.instance, required this.query});

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
        final filtered = filterByTitle(downloads, query,
            (d) => aria2DisplayName(d as Map<String, dynamic>));
        if (filtered.isEmpty) {
          return const Center(child: Text('No matches'));
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(_aria2DownloadsProvider(instance)),
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) => _Aria2Tile(
              download: filtered[index] as Map<String, dynamic>,
              trailing: _ActiveActions(
                download: filtered[index] as Map<String, dynamic>,
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
  final String query;

  const _HistoryTab({required this.instance, required this.query});

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
        final filtered = filterByTitle(downloads, query,
            (d) => aria2DisplayName(d as Map<String, dynamic>));
        if (filtered.isEmpty) {
          return const Center(child: Text('No matches'));
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(_aria2StoppedProvider(instance)),
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final download = filtered[index] as Map<String, dynamic>;
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
    final name = aria2DisplayName(download);

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
