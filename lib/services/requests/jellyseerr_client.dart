import 'dart:convert';
import 'package:http/http.dart' as http;
import '../arr/arr_exception.dart';

/// Jellyseerr's REST API lives at `/api/v1/` and authenticates via an
/// `X-Api-Key` header, same convention as Servarr, but its resource shapes
/// (media requests, discover results) are different enough to warrant its
/// own client rather than extending ServarrClient.
class JellyseerrClient {
  final String baseUrl;
  final String apiKey;
  final http.Client _http;

  JellyseerrClient({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$cleanBase/api/v1/$cleanPath');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Map<String, String> get _headers => {
        'X-Api-Key': apiKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<dynamic> _get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<dynamic> _post(String path, {Object? body}) => _send(() => _http.post(
        _uri(path),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ));

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ArrException.network(e);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw ArrException.unauthorized();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ArrException.unexpectedStatus(response.statusCode, response.body);
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<bool> checkHealth() async {
    try {
      await _get('status');
      return true;
    } on ArrException {
      return false;
    }
  }

  Future<List<dynamic>> getRequests({String filter = 'all'}) async {
    final result = await _get('request', query: {
      'filter': filter,
      'take': 100,
      'sort': 'added',
    });
    return (result as Map<String, dynamic>)['results'] as List<dynamic>;
  }

  Future<List<dynamic>> searchMedia(String query) async {
    final result = await _get('search', query: {'query': query});
    return (result as Map<String, dynamic>)['results'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> requestMedia({
    required int mediaId,
    required String mediaType, // 'movie' | 'tv'
    List<int>? seasons,
  }) async {
    final body = {
      'mediaId': mediaId,
      'mediaType': mediaType,
      if (seasons != null) 'seasons': seasons,
    };
    final result = await _post('request', body: body);
    return result as Map<String, dynamic>;
  }

  Future<void> updateRequestStatus(int requestId, String status) async {
    // status: 'approve' | 'decline'
    await _post('request/$requestId/$status');
  }

  /// Jellyseerr's /request list only embeds media ids (tmdbId, mediaType),
  /// not the title — this proxies TMDB's own movie/tv detail endpoint
  /// through Jellyseerr to fill that in for display.
  Future<Map<String, dynamic>> getMediaDetails({
    required int tmdbId,
    required String mediaType, // 'movie' | 'tv'
  }) async {
    final path = mediaType == 'tv' ? 'tv/$tmdbId' : 'movie/$tmdbId';
    final result = await _get(path);
    return result as Map<String, dynamic>;
  }

  void close() => _http.close();
}
