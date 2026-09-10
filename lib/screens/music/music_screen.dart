import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/artist.dart';
import '../../models/instance_config.dart';
import '../../services/arr/lidarr_client.dart';
import '../../services/storage/instance_repository.dart';

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
class MusicScreen extends ConsumerWidget {
  final InstanceConfig instance;

  const MusicScreen({super.key, required this.instance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(_artistsProvider(instance));

    return Scaffold(
      appBar: AppBar(title: Text(instance.label)),
      body: artistsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (artists) {
          if (artists.isEmpty) {
            return const Center(child: Text('No artists in library'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_artistsProvider(instance)),
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                childAspectRatio: 0.8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: artists.length,
              itemBuilder: (context, index) =>
                  _ArtistTile(artist: artists[index], instance: instance),
            ),
          );
        },
      ),
    );
  }
}

class _ArtistTile extends ConsumerWidget {
  final Artist artist;
  final InstanceConfig instance;

  const _ArtistTile({required this.artist, required this.instance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onLongPress: () async {
        final client = await ref.read(_lidarrClientProvider(instance).future);
        await client.setArtistMonitored(artist.id, !artist.monitored);
        ref.invalidate(_artistsProvider(instance));
      },
      child: Column(
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
                Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(
                    artist.monitored ? Icons.bookmark : Icons.bookmark_border,
                    color: Colors.white,
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
      ),
    );
  }
}
