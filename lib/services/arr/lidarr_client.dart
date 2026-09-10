import '../../models/album.dart';
import '../../models/artist.dart';
import 'servarr_client.dart';

class LidarrClient extends ServarrClient {
  LidarrClient({required super.baseUrl, required super.apiKey})
      : super(apiVersion: 'v1');

  Future<List<Artist>> getArtists() async {
    final result = await get('artist') as List<dynamic>;
    return result
        .map((e) => Artist.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Album>> getAlbums(int artistId) async {
    final result =
        await get('album', query: {'artistId': artistId}) as List<dynamic>;
    return result
        .map((e) => Album.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setArtistMonitored(int artistId, bool monitored) async {
    final artist = await get('artist/$artistId') as Map<String, dynamic>;
    artist['monitored'] = monitored;
    await put('artist/$artistId', body: artist);
  }

  Future<void> deleteArtist(int id, {bool deleteFiles = false}) async {
    await delete('artist/$id?deleteFiles=$deleteFiles');
  }

  Future<void> searchArtist(int id) async {
    await post('command', body: {
      'name': 'ArtistSearch',
      'artistId': id,
    });
  }

  /// Bulk monitor/unmonitor/delete via the editor endpoint, matching
  /// what Lidarr's own web UI does for multi-select actions.
  Future<void> setMonitoredBulk(List<int> artistIds, bool monitored) async {
    await put('artist/editor', body: {
      'artistIds': artistIds,
      'monitored': monitored,
    });
  }

  Future<void> deleteArtistsBulk(List<int> artistIds,
      {bool deleteFiles = false}) async {
    await deleteWithBody('artist/editor', body: {
      'artistIds': artistIds,
      'deleteFiles': deleteFiles,
    });
  }

  Future<void> searchArtistsBulk(List<int> artistIds) async {
    for (final id in artistIds) {
      await post('command', body: {'name': 'ArtistSearch', 'artistId': id});
    }
  }

  Future<List<dynamic>> lookupArtist(String term) async {
    final result = await get('artist/lookup', query: {'term': term});
    return result as List<dynamic>;
  }

  Future<Artist> addArtist({
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
      'addOptions': {'searchForMissingAlbums': searchOnAdd},
    };
    final result = await post('artist', body: payload) as Map<String, dynamic>;
    return Artist.fromJson(result);
  }

  Future<List<dynamic>> getRootFolders() async {
    final result = await get('rootfolder');
    return result as List<dynamic>;
  }

  Future<List<dynamic>> getQueue() async {
    final result = await get('queue', query: {'pageSize': 200});
    return (result as Map<String, dynamic>)['records'] as List<dynamic>;
  }
}
