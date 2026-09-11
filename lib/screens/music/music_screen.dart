import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/artist.dart';
import '../../models/instance_config.dart';
import '../../services/arr/lidarr_client.dart';
import '../../services/storage/instance_repository.dart';
import '../shared/add_media_screen.dart';
import '../shared/library_search_bar.dart';
import '../shared/quality_profiles_screen.dart';
import '../shared/queue_tab.dart';
import '../shared/selectable_grid.dart';
import 'artist_detail_screen.dart';

final _lidarrClientProvider =
    FutureProvider.family<LidarrClient, InstanceConfig>((ref, instance) async {
  final repo = InstanceRepository();
  final apiKey = await repo.getApiKey(instance.id);
  return LidarrClient(baseUrl: instance.baseUrl, apiKey: apiKey ?? '');
});

final _artistsProvider =
    FutureProvider.family<List<Artist>, InstanceConfig>((ref, instance) async {
  final client = await ref.watch(_lidarrClientProvider(instance).future);
  return client.getArtists();
});

/// Lidarr library screen: browse + monitor toggle, same shape as
/// MoviesScreen/TvScreen but for artists.
class MusicScreen extends ConsumerStatefulWidget {
  final InstanceConfig instance;

  const MusicScreen({super.key, required this.instance});

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen> {
  String _query = '';

  InstanceConfig get instance => widget.instance;

  @override
  Widget build(BuildContext context) {
    final artistsAsync = ref.watch(_artistsProvider(instance));

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
                    await ref.read(_lidarrClientProvider(instance).future);
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
          tooltip: 'Add artist',
          onPressed: () async {
            final client =
                await ref.read(_lidarrClientProvider(instance).future);
            final existingArtists = await client.getArtists();
            final existingForeignIds = existingArtists
                .map((a) => a.foreignArtistId)
                .whereType<String>()
                .toSet();

            if (!context.mounted) return;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddMediaScreen(
                  serviceLabel: instance.label,
                  onSearch: client.lookupArtist,
                  onLoadQualityProfiles: client.getQualityProfiles,
                  onLoadRootFolders: client.getRootFolders,
                  onAdd: ({
                    required lookupResult,
                    required qualityProfileId,
                    required rootFolderPath,
                    required monitored,
                    required searchOnAdd,
                  }) =>
                      client.addArtist(
                    lookupResult: lookupResult,
                    qualityProfileId: qualityProfileId,
                    rootFolderPath: rootFolderPath,
                    monitored: monitored,
                    searchOnAdd: searchOnAdd,
                  ),
                  titleOf: (r) => r['artistName'] as String? ?? 'Unknown',
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
                  alreadyAdded: (r) => existingForeignIds
                      .contains(r['foreignArtistId'] as String?),
                ),
              ),
            );
            ref.invalidate(_artistsProvider(instance));
          },
          child: const Icon(Icons.add),
        ),
        body: TabBarView(
          children: [
            artistsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (artists) {
                if (artists.isEmpty) {
                  return const Center(child: Text('No artists in library'));
                }
                final filtered =
                    filterByTitle(artists, _query, (a) => a.artistName);
                if (filtered.isEmpty) {
                  return const Center(child: Text('No matches'));
                }
                return SelectableGrid<Artist>(
                  items: filtered,
                  idOf: (a) => a.id,
                  onRefresh: () async =>
                      ref.invalidate(_artistsProvider(instance)),
                  onActionCompleted: () =>
                      ref.invalidate(_artistsProvider(instance)),
                  onTapItem: (artist) async {
                    final client =
                        await ref.read(_lidarrClientProvider(instance).future);
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ArtistDetailScreen(
                          client: client,
                          artist: artist,
                          onChanged: () =>
                              ref.invalidate(_artistsProvider(instance)),
                        ),
                      ),
                    );
                  },
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  actions: [
                    BulkAction(
                      icon: Icons.bookmark,
                      label: 'Monitor',
                      onRun: (ids) async {
                        final client = await ref
                            .read(_lidarrClientProvider(instance).future);
                        await client.setMonitoredBulk(ids, true);
                      },
                    ),
                    BulkAction(
                      icon: Icons.bookmark_border,
                      label: 'Unmonitor',
                      onRun: (ids) async {
                        final client = await ref
                            .read(_lidarrClientProvider(instance).future);
                        await client.setMonitoredBulk(ids, false);
                      },
                    ),
                    BulkAction(
                      icon: Icons.search,
                      label: 'Search',
                      onRun: (ids) async {
                        final client = await ref
                            .read(_lidarrClientProvider(instance).future);
                        await client.searchArtistsBulk(ids);
                      },
                    ),
                    BulkAction(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      destructive: true,
                      onRun: (ids) async {
                        final client = await ref
                            .read(_lidarrClientProvider(instance).future);
                        await client.deleteArtistsBulk(ids);
                      },
                    ),
                  ],
                  itemBuilder: (context, artist, selected, onToggle) =>
                      _ArtistTile(artist: artist, selected: selected),
                );
              },
            ),
            QueueTab(
              onLoadQueue: () async {
                final client =
                    await ref.read(_lidarrClientProvider(instance).future);
                return client.getQueue();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistTile extends StatelessWidget {
  final Artist artist;
  final bool selected;

  const _ArtistTile({required this.artist, required this.selected});

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
                child: artist.posterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: artist.posterUrl!,
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
                      : artist.monitored
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
        Text(artist.artistName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
