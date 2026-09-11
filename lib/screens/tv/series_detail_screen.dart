import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/episode.dart';
import '../../models/instance_config.dart';
import '../../models/series.dart';
import '../../services/arr/sonarr_client.dart';
import '../../services/storage/instance_repository.dart';
import '../shared/media_detail_header.dart';

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
/// this as the series detail page. A metadata header (overview, genres,
/// rating) sits above the season list; seasons are collapsible with each
/// episode row having a monitor toggle and a per-episode search action.
class SeriesDetailScreen extends ConsumerStatefulWidget {
  final InstanceConfig instance;
  final Series series;
  final VoidCallback? onChanged;

  const SeriesDetailScreen({
    super.key,
    required this.instance,
    required this.series,
    this.onChanged,
  });

  @override
  ConsumerState<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  late Series _series;

  InstanceConfig get instance => widget.instance;

  @override
  void initState() {
    super.initState();
    _series = widget.series;
  }

  Future<void> _toggleMonitored() async {
    final client = await ref.read(_sonarrClientProvider(instance).future);
    await client.setMonitored(_series.id, !_series.monitored);
    final refreshed = await client.getSeriesById(_series.id);
    if (!mounted) return;
    setState(() => _series = refreshed);
    widget.onChanged?.call();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${_series.title}"?'),
        content: const Text('This removes the series from Sonarr.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final client = await ref.read(_sonarrClientProvider(instance).future);
    await client.deleteSeries(_series.id);
    widget.onChanged?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final episodesAsync = ref.watch(_episodesProvider((instance, _series.id)));

    final subtitleParts = [
      '${_series.year}',
      if (_series.network != null) _series.network!,
      if (_series.runtime != null) '${_series.runtime} min',
      _series.status,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_series.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search entire series',
            onPressed: () async {
              final client =
                  await ref.read(_sonarrClientProvider(instance).future);
              await client.searchSeries(_series.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Searching for ${_series.title}')),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _delete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: episodesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (episodes) {
          final bySeason = groupEpisodesBySeason(episodes);
          final seasonNumbers = bySeason.keys.toList()..sort();

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(_episodesProvider((instance, _series.id))),
            child: ListView(
              children: [
                MediaDetailHeader(
                  posterUrl: _series.posterUrl,
                  title: _series.title,
                  subtitle: subtitleParts.join(' · '),
                  genres: _series.genres,
                  rating: _series.rating,
                  overview: _series.overview,
                ),
                SwitchListTile(
                  title: const Text('Monitored'),
                  value: _series.monitored,
                  onChanged: (_) => _toggleMonitored(),
                ),
                const Divider(height: 1),
                if (episodes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No episodes found'),
                  )
                else
                  for (final seasonNumber in seasonNumbers)
                    _SeasonExpansionTile(
                      seasonNumber: seasonNumber,
                      episodes: bySeason[seasonNumber]!,
                      instance: instance,
                      series: _series,
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
