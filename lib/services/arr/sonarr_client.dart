import '../../models/episode.dart';
import '../../models/series.dart';
import 'servarr_client.dart';

class SonarrClient extends ServarrClient {
  SonarrClient({required super.baseUrl, required super.apiKey})
      : super(apiVersion: 'v3');

  Future<List<Series>> getSeries() async {
    final result = await get('series') as List<dynamic>;
    return result
        .map((e) => Series.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Series> getSeriesById(int id) async {
    final result = await get('series/$id') as Map<String, dynamic>;
    return Series.fromJson(result);
  }

  Future<List<Episode>> getEpisodes(int seriesId) async {
    final result =
        await get('episode', query: {'seriesId': seriesId}) as List<dynamic>;
    return result
        .map((e) => Episode.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setMonitored(int seriesId, bool monitored) async {
    final series = await get('series/$seriesId') as Map<String, dynamic>;
    series['monitored'] = monitored;
    await put('series/$seriesId', body: series);
  }

  Future<void> setEpisodeMonitored(int episodeId, bool monitored) async {
    await put('episode/monitor', body: {
      'episodeIds': [episodeId],
      'monitored': monitored,
    });
  }

  Future<void> deleteSeries(int id, {bool deleteFiles = false}) async {
    await delete('series/$id?deleteFiles=$deleteFiles');
  }

  Future<void> searchSeries(int id) async {
    await post('command', body: {
      'name': 'SeriesSearch',
      'seriesId': id,
    });
  }

  Future<void> searchEpisode(int episodeId) async {
    await post('command', body: {
      'name': 'EpisodeSearch',
      'episodeIds': [episodeId],
    });
  }

  Future<List<dynamic>> lookupSeries(String term) async {
    final result = await get('series/lookup', query: {'term': term});
    return result as List<dynamic>;
  }

  Future<Series> addSeries({
    required Map<String, dynamic> lookupResult,
    required int qualityProfileId,
    required String rootFolderPath,
    bool monitored = true,
    bool searchOnAdd = true,
  }) async {
    final payload = {
      ...lookupResult,
      'qualityProfileId': qualityProfileId,
      'rootFolderPath': rootFolderPath,
      'monitored': monitored,
      'addOptions': {'searchForMissingEpisodes': searchOnAdd},
    };
    final result = await post('series', body: payload) as Map<String, dynamic>;
    return Series.fromJson(result);
  }

  Future<List<dynamic>> getQualityProfiles() async {
    final result = await get('qualityprofile');
    return result as List<dynamic>;
  }

  Future<List<dynamic>> getRootFolders() async {
    final result = await get('rootfolder');
    return result as List<dynamic>;
  }

  Future<List<dynamic>> getCalendar({DateTime? start, DateTime? end}) async {
    final query = <String, dynamic>{};
    if (start != null) query['start'] = start.toIso8601String();
    if (end != null) query['end'] = end.toIso8601String();
    final result = await get('calendar', query: query);
    return result as List<dynamic>;
  }

  Future<List<dynamic>> getQueue() async {
    final result = await get('queue', query: {'pageSize': 200});
    return (result as Map<String, dynamic>)['records'] as List<dynamic>;
  }
}
