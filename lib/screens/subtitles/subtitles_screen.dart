import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/instance_config.dart';
import '../../services/arr/bazarr_client.dart';
import '../../services/storage/instance_repository.dart';
import '../shared/library_search_bar.dart';

final _bazarrClientProvider =
    FutureProvider.family<BazarrClient, InstanceConfig>((ref, instance) async {
  final repo = InstanceRepository();
  final apiKey = await repo.getApiKey(instance.id);
  return BazarrClient(baseUrl: instance.baseUrl, apiKey: apiKey ?? '');
});

final _wantedProvider =
    FutureProvider.family<List<dynamic>, InstanceConfig>((ref, instance) async {
  final client = await ref.watch(_bazarrClientProvider(instance).future);
  final movies = await client.getWantedMovies();
  final episodes = await client.getWantedEpisodes();
  return [...movies, ...episodes];
});

/// Extracts the display title and subtitle line for one wanted-subtitle
/// row. Pulled out as a pure function so the real Bazarr field names
/// (confirmed against a live instance: episodes use `episodeTitle`
/// camelCase and `episode_number` snake_case as a "1x22"-style string,
/// not the `episode_title` this originally assumed) are unit-testable
/// without a fake BazarrClient.
({String title, String? subtitle}) wantedItemDisplay(
    Map<String, dynamic> item) {
  final title = item['title'] as String? ?? item['seriesTitle'] as String?;
  final episodeTitle = item['episodeTitle'] as String?;
  final episodeNumber = item['episode_number'] as String?;
  final subtitleParts = [
    if (episodeNumber != null) episodeNumber,
    if (episodeTitle != null) episodeTitle,
  ];
  return (
    title: title ?? 'Unknown',
    subtitle: subtitleParts.isEmpty ? null : subtitleParts.join(' · '),
  );
}

/// Bazarr wanted-subtitles screen: what's missing subtitles across movies
/// and episodes, mirroring Bazarr's own "Wanted" tab.
class SubtitlesScreen extends ConsumerStatefulWidget {
  final InstanceConfig instance;

  const SubtitlesScreen({super.key, required this.instance});

  @override
  ConsumerState<SubtitlesScreen> createState() => _SubtitlesScreenState();
}

class _SubtitlesScreenState extends ConsumerState<SubtitlesScreen> {
  String _query = '';

  InstanceConfig get instance => widget.instance;

  @override
  Widget build(BuildContext context) {
    final wantedAsync = ref.watch(_wantedProvider(instance));

    return Scaffold(
      appBar: AppBar(
        title: Text(instance.label),
        actions: [
          LibrarySearchBar(
            hintText: 'Search wanted...',
            onQueryChanged: (q) => setState(() => _query = q),
          ),
        ],
      ),
      body: wantedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No wanted subtitles'));
          }
          final filtered = filterByTitle(items, _query,
              (i) => wantedItemDisplay(i as Map<String, dynamic>).title);
          if (filtered.isEmpty) {
            return const Center(child: Text('No matches'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_wantedProvider(instance)),
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index] as Map<String, dynamic>;
                final display = wantedItemDisplay(item);
                return ListTile(
                  leading: const Icon(Icons.subtitles_outlined),
                  title: Text(display.title),
                  subtitle:
                      display.subtitle != null ? Text(display.subtitle!) : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
