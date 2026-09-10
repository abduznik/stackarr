import '../../models/movie.dart';
import 'servarr_client.dart';

class RadarrClient extends ServarrClient {
  RadarrClient({required super.baseUrl, required super.apiKey})
      : super(apiVersion: 'v3');

  Future<List<Movie>> getMovies() async {
    final result = await get('movie') as List<dynamic>;
    return result
        .map((e) => Movie.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Movie> getMovie(int id) async {
    final result = await get('movie/$id') as Map<String, dynamic>;
    return Movie.fromJson(result);
  }

  Future<void> setMonitored(int id, bool monitored) async {
    final movie = await get('movie/$id') as Map<String, dynamic>;
    movie['monitored'] = monitored;
    await put('movie/$id', body: movie);
  }

  Future<void> deleteMovie(int id, {bool deleteFiles = false}) async {
    await delete('movie/$id?deleteFiles=$deleteFiles');
  }

  Future<void> searchMovie(int id) async {
    await post('command', body: {
      'name': 'MoviesSearch',
      'movieIds': [id],
    });
  }

  Future<List<dynamic>> lookupMovie(String term) async {
    final result = await get('movie/lookup', query: {'term': term});
    return result as List<dynamic>;
  }

  Future<Movie> addMovie({
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
      'addOptions': {'searchForMovie': searchOnAdd},
    };
    final result = await post('movie', body: payload) as Map<String, dynamic>;
    return Movie.fromJson(result);
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
