import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/episode.dart';
import '../../models/instance_config.dart';
import '../../models/series.dart';
import '../../services/arr/sonarr_client.dart';
import '../../services/storage/instance_repository.dart';

final _sonarrClientProvider =
    FutureProvider.family<SonarrClient, InstanceConfig>((ref, instance) async {
  final repo = InstanceRepository();
  final apiKey = await repo.getApiKey(instance.id);
  return SonarrClient(baseUrl: instance.baseUrl, apiKey: apiKey ?? '');
});

final _episodesProvider =
    FutureProvider.family<List<Episode>, (InstanceConfig, int)>(
        (ref, args) async {
  final (instance, seriesId) = args;
  final client = await ref.watch(_sonarrClientProvider(instance).future);
  return client.getEpisodes(seriesId);
});

/// Groups episodes by season number and sorts each group by episode
/// number — pulled out as a pure function so it's unit-testable without
/// standing up a fake SonarrClient.
Map<int, List<Episode>> groupEpisodesBySeason(List<Episode> episodes) {
  final bySeason = <int, List<Episode>>{};
  for (final ep in episodes) {
    bySeason.putIfAbsent(ep.seasonNumber, () => []).add(ep);
  }
  for (final list in bySeason.values) {
    list.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
  }
  return bySeason;
}

/// Season/episode breakdown for one series — Sonarr's own web UI shows
/// this as the series detail page. Seasons are collapsible; each episode
/// row has a monitor toggle and a per-episode search action.
class SeriesDetailScreen extends ConsumerWidget {
  final InstanceConfig instance;
  final Series series;

  const SeriesDetailScreen(
      {super.key, required this.instance, required this.series});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodesAsync = ref.watch(_episodesProvider((instance, series.id)));

    return Scaffold(
      appBar: AppBar(
        title: Text(series.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search entire series',
            onPressed: () async {
              final client =
                  await ref.read(_sonarrClientProvider(instance).future);
              await client.searchSeries(series.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Searching for ${series.title}')),
                );
              }
            },
          ),
        ],
      ),
      body: episodesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (episodes) {
          if (episodes.isEmpty) {
            return const Center(child: Text('No episodes found'));
          }
          final bySeason = groupEpisodesBySeason(episodes);
          final seasonNumbers = bySeason.keys.toList()..sort();

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(_episodesProvider((instance, series.id))),
            child: ListView(
              children: [
                for (final seasonNumber in seasonNumbers)
                  _SeasonExpansionTile(
                    seasonNumber: seasonNumber,
                    episodes: bySeason[seasonNumber]!,
                    instance: instance,
                    series: series,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SeasonExpansionTile extends ConsumerWidget {
  final int seasonNumber;
  final List<Episode> episodes;
  final InstanceConfig instance;
  final Series series;

  const _SeasonExpansionTile({
    required this.seasonNumber,
    required this.episodes,
    required this.instance,
    required this.series,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloaded = episodes.where((e) => e.hasFile).length;
    final label = seasonNumber == 0 ? 'Specials' : 'Season $seasonNumber';

    return ExpansionTile(
      title: Text(label),
      subtitle: Text('$downloaded / ${episodes.length} downloaded'),
      children: [
        for (final episode in episodes)
          _EpisodeTile(episode: episode, instance: instance, series: series),
      ],
    );
  }
}

class _EpisodeTile extends ConsumerWidget {
  final Episode episode;
  final InstanceConfig instance;
  final Series series;

  const _EpisodeTile({
    required this.episode,
    required this.instance,
    required this.series,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(
        episode.hasFile ? Icons.check_circle : Icons.radio_button_unchecked,
        color: episode.hasFile ? Colors.green : null,
      ),
      title: Text('${episode.episodeNumber}. ${episode.title}'),
      subtitle: episode.airDate != null ? Text(episode.airDate!) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search this episode',
            onPressed: () async {
              final client =
                  await ref.read(_sonarrClientProvider(instance).future);
              await client.searchEpisode(episode.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Searching for episode ${episode.episodeNumber}')),
                );
              }
            },
          ),
          Switch(
            value: episode.monitored,
            onChanged: (value) async {
              final client =
                  await ref.read(_sonarrClientProvider(instance).future);
              await client.setEpisodeMonitored(episode.id, value);
              ref.invalidate(_episodesProvider((instance, series.id)));
            },
          ),
        ],
      ),
    );
  }
}
