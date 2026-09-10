import '../../models/indexer.dart';
import 'arr_exception.dart';
import 'servarr_client.dart';

class ProwlarrClient extends ServarrClient {
  ProwlarrClient({required super.baseUrl, required super.apiKey})
      : super(apiVersion: 'v1');

  Future<List<Indexer>> getIndexers() async {
    final result = await get('indexer') as List<dynamic>;
    return result
        .map((e) => Indexer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setIndexerEnabled(int id, bool enabled) async {
    final indexer = await get('indexer/$id') as Map<String, dynamic>;
    indexer['enable'] = enabled;
    await put('indexer/$id', body: indexer);
  }

  Future<void> deleteIndexer(int id) async {
    await delete('indexer/$id');
  }

  Future<bool> testIndexer(int id) async {
    try {
      await post('indexer/$id/test');
      return true;
    } on ArrException {
      return false;
    }
  }

  Future<void> syncAllIndexers() async {
    await post('command', body: {'name': 'ApplicationIndexerSync'});
  }

  Future<List<dynamic>> getApplications() async {
    final result = await get('applications');
    return result as List<dynamic>;
  }
}
