import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/instance_config.dart';
import '../../models/series.dart';
import '../../services/arr/sonarr_client.dart';
import '../../services/storage/instance_repository.dart';
import '../shared/add_media_screen.dart';
import '../shared/library_search_bar.dart';
import '../shared/quality_profiles_screen.dart';
import '../shared/queue_tab.dart';
import '../shared/selectable_grid.dart';
import 'series_detail_screen.dart';

final _sonarrClientProvider =
    FutureProvider.family<SonarrClient, InstanceConfig>((ref, instance) async {
  final repo = InstanceRepository();
  final apiKey = await repo.getApiKey(instance.id);
  return SonarrClient(baseUrl: instance.baseUrl, apiKey: apiKey ?? '');
});

final _seriesProvider =
    FutureProvider.family<List<Series>, InstanceConfig>((ref, instance) async {
  final client = await ref.watch(_sonarrClientProvider(instance).future);
  return client.getSeries();
});

/// Sonarr library screen: browse + monitor toggle, mirroring MoviesScreen's
/// shape for Radarr — same interaction model, different backing client.
class TvScreen extends ConsumerStatefulWidget {
  final InstanceConfig instance;

  const TvScreen({super.key, required this.instance});

  @override
  ConsumerState<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends ConsumerState<TvScreen> {
  String _query = '';

  InstanceConfig get instance => widget.instance;

  @override
  Widget build(BuildContext context) {
    final seriesAsync = ref.watch(_seriesProvider(instance));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(instance.label),
          actions: [
            LibrarySearchBar(
              hintText: 'Search library...',
              onQueryChanged: (q) => setState(() => _query = q),
            ),
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Quality profiles',
              onPressed: () async {
                final client =
                    await ref.read(_sonarrClientProvider(instance).future);
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QualityProfilesScreen(client: client),
                  ),
                );
              },
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Library'),
            Tab(text: 'Activity'),
          ]),
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Add series',
          onPressed: () async {
            final client =
                await ref.read(_sonarrClientProvider(instance).future);
            final existingSeries = await client.getSeries();
            final existingTvdbIds =
                existingSeries.map((s) => s.tvdbId).whereType<int>().toSet();

            if (!context.mounted) return;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddMediaScreen(
                  serviceLabel: instance.label,
                  onSearch: client.lookupSeries,
                  onLoadQualityProfiles: client.getQualityProfiles,
                  onLoadRootFolders: client.getRootFolders,
                  onAdd: ({
                    required lookupResult,
                    required qualityProfileId,
                    required rootFolderPath,
                    required monitored,
                    required searchOnAdd,
                  }) =>
                      client.addSeries(
                    lookupResult: lookupResult,
                    qualityProfileId: qualityProfileId,
                    rootFolderPath: rootFolderPath,
                    monitored: monitored,
                    searchOnAdd: searchOnAdd,
                  ),
                  titleOf: (r) => '${r['title']} (${r['year'] ?? '?'})',
                  posterUrlOf: (r) {
                    final images = (r['images'] as List<dynamic>?) ?? [];
                    for (final img in images) {
                      if (img['coverType'] == 'poster') {
                        return img['remoteUrl'] as String? ??
                            img['url'] as String?;
                      }
                    }
                    return null;
                  },
                  alreadyAdded: (r) =>
                      existingTvdbIds.contains(r['tvdbId'] as int?),
                ),
              ),
            );
            ref.invalidate(_seriesProvider(instance));
          },
          child: const Icon(Icons.add),
        ),
        body: TabBarView(
          children: [
            seriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (series) {
                if (series.isEmpty) {
                  return const Center(child: Text('No series in library'));
                }
                final filtered = filterByTitle(series, _query, (s) => s.title);
                if (filtered.isEmpty) {
                  return const Center(child: Text('No matches'));
                }
                return SelectableGrid<Series>(
                  items: filtered,
                  idOf: (s) => s.id,
                  onRefresh: () async =>
                      ref.invalidate(_seriesProvider(instance)),
                  onActionCompleted: () =>
                      ref.invalidate(_seriesProvider(instance)),
                  onTapItem: (s) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SeriesDetailScreen(
                          instance: instance,
                          series: s,
                          onChanged: () =>
                              ref.invalidate(_seriesProvider(instance)),
                        ),
                      ),
                    );
                  },
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    childAspectRatio: 0.6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  actions: [
                    BulkAction(
                      icon: Icons.bookmark,
                      label: 'Monitor',
                      onRun: (ids) async {
                        final client = await ref
                            .read(_sonarrClientProvider(instance).future);
                        await client.setMonitoredBulk(ids, true);
                      },
                    ),
                    BulkAction(
                      icon: Icons.bookmark_border,
                      label: 'Unmonitor',
                      onRun: (ids) async {
                        final client = await ref
                            .read(_sonarrClientProvider(instance).future);
                        await client.setMonitoredBulk(ids, false);
                      },
                    ),
                    BulkAction(
                      icon: Icons.search,
                      label: 'Search',
                      onRun: (ids) async {
                        final client = await ref
                            .read(_sonarrClientProvider(instance).future);
                        await client.searchSeriesBulk(ids);
                      },
                    ),
                    BulkAction(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      destructive: true,
                      onRun: (ids) async {
                        final client = await ref
                            .read(_sonarrClientProvider(instance).future);
                        await client.deleteSeriesBulk(ids);
                      },
                    ),
                  ],
                  itemBuilder: (context, series, selected, onToggle) =>
                      _SeriesTile(series: series, selected: selected),
                );
              },
            ),
            QueueTab(
              onLoadQueue: () async {
                final client =
                    await ref.read(_sonarrClientProvider(instance).future);
                return client.getQueue();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SeriesTile extends StatelessWidget {
  final Series series;
  final bool selected;

  const _SeriesTile({required this.series, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: series.posterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: series.posterUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const ColoredBox(color: Colors.black12),
                      )
                    : const ColoredBox(color: Colors.black12),
              ),
              if (selected)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.primary, width: 3),
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.2),
                  ),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  selected
                      ? Icons.check_circle
                      : series.monitored
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white,
                  shadows: const [Shadow(blurRadius: 4)],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(series.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
