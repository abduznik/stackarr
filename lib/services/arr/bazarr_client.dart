import 'dart:convert';
import 'package:http/http.dart' as http;
import 'arr_exception.dart';

/// Bazarr's REST API lives at `/api/` (not versioned like Servarr) and
/// authenticates via an `X-API-KEY` header — same idea as Servarr but a
/// different header name, so it doesn't share ServarrClient's transport.
class BazarrClient {
  final String baseUrl;
  final String apiKey;
  final http.Client _http;

  BazarrClient({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$cleanBase/api/$cleanPath');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Map<String, String> get _headers => {
        'X-API-KEY': apiKey,
        'Accept': 'application/json',
      };

  Future<dynamic> _get(String path, {Map<String, dynamic>? query}) async {
    http.Response response;
    try {
      response = await _http
          .get(_uri(path, query), headers: _headers)
          .timeout(const Duration(seconds: 15));
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
      await _get('system/status');
      return true;
    } on ArrException {
      return false;
    }
  }

  Future<List<dynamic>> getWantedMovies() async {
    final result = await _get('movies/wanted');
    return (result as Map<String, dynamic>)['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getWantedEpisodes() async {
    final result = await _get('episodes/wanted');
    return (result as Map<String, dynamic>)['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getLanguages() async {
    final result = await _get('system/languages');
    return result as List<dynamic>;
  }

  void close() => _http.close();
}
