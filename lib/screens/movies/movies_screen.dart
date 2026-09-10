import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/instance_config.dart';
import '../../models/movie.dart';
import '../../services/arr/radarr_client.dart';
import '../../services/storage/instance_repository.dart';

final _radarrClientProvider =
    FutureProvider.family<RadarrClient, InstanceConfig>((ref, instance) async {
  final repo = InstanceRepository();
  final apiKey = await repo.getApiKey(instance.id);
  return RadarrClient(baseUrl: instance.baseUrl, apiKey: apiKey ?? '');
});

final _moviesProvider =
    FutureProvider.family<List<Movie>, InstanceConfig>((ref, instance) async {
  final client = await ref.watch(_radarrClientProvider(instance).future);
  return client.getMovies();
});

/// Radarr library screen: browse + search + monitor toggle, same actions
/// Radarr's own web UI exposes, driven entirely through RadarrClient.
class MoviesScreen extends ConsumerWidget {
  final InstanceConfig instance;

  const MoviesScreen({super.key, required this.instance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(_moviesProvider(instance));

    return Scaffold(
      appBar: AppBar(title: Text(instance.label)),
      body: moviesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (movies) {
          if (movies.isEmpty) {
            return const Center(child: Text('No movies in library'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_moviesProvider(instance)),
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                childAspectRatio: 0.6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: movies.length,
              itemBuilder: (context, index) =>
                  _MovieTile(movie: movies[index], instance: instance),
            ),
          );
        },
      ),
    );
  }
}

class _MovieTile extends ConsumerWidget {
  final Movie movie;
  final InstanceConfig instance;

  const _MovieTile({required this.movie, required this.instance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onLongPress: () async {
        final client = await ref.read(_radarrClientProvider(instance).future);
        await client.setMonitored(movie.id, !movie.monitored);
        ref.invalidate(_moviesProvider(instance));
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
                  child: movie.posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: movie.posterUrl!,
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
                    movie.monitored ? Icons.bookmark : Icons.bookmark_border,
                    color: Colors.white,
                    shadows: const [Shadow(blurRadius: 4)],
                  ),
                ),
                if (movie.hasFile)
                  const Positioned(
                    bottom: 4,
                    left: 4,
                    child:
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(movie.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
