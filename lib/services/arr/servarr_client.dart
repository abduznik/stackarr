import 'dart:convert';
import 'package:http/http.dart' as http;
import 'arr_exception.dart';

/// Base HTTP client for the Servarr family (Radarr, Sonarr, Lidarr,
/// Prowlarr) — they share the same auth (`X-Api-Key` header), the same
/// envelope-free JSON REST shape, and the same `/system/status` health
/// endpoint, differing only in resource paths and payload shapes.
///
/// Concrete clients (RadarrClient, SonarrClient, ...) extend this and add
/// their own typed endpoints; this class only owns transport concerns.
abstract class ServarrClient {
  final String baseUrl;
  final String apiKey;
  final http.Client _http;

  /// e.g. "v3" for Radarr/Sonarr/Lidarr, "v1" for Prowlarr.
  final String apiVersion;

  ServarrClient({
    required this.baseUrl,
    required this.apiKey,
    required this.apiVersion,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final url = '$cleanBase/api/$apiVersion/$cleanPath';
    final uri = Uri.parse(url);
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        ...query.map((k, v) => MapEntry(k, v.toString())),
      },
    );
  }

  Map<String, String> get _headers => {
        'X-Api-Key': apiKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    return _send(() => _http.get(_uri(path, query), headers: _headers));
  }

  Future<dynamic> post(String path, {Object? body}) async {
    return _send(() => _http.post(
          _uri(path),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        ));
  }

  Future<dynamic> put(String path, {Object? body}) async {
    return _send(() => _http.put(
          _uri(path),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        ));
  }

  Future<dynamic> delete(String path) async {
    return _send(() => _http.delete(_uri(path), headers: _headers));
  }

  /// Bulk-delete endpoints (e.g. `movie/editor`, `series/editor`) take the
  /// id list in a JSON body rather than the URL, which package:http's
  /// [http.Client.delete] supports via its optional `body` param even
  /// though [delete] above doesn't expose one.
  Future<dynamic> deleteWithBody(String path, {required Object body}) async {
    return _send(() => _http.delete(
          _uri(path),
          headers: _headers,
          body: jsonEncode(body),
        ));
  }

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
    if (response.statusCode == 404) {
      throw ArrException.notFound();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ArrException.unexpectedStatus(response.statusCode, response.body);
    }
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } catch (e) {
      throw ArrException('Could not parse server response', cause: e);
    }
  }

  /// Hits `/system/status` — used by the setup wizard's health check step
  /// and by settings to verify a saved instance is still reachable.
  Future<bool> checkHealth() async {
    try {
      final result = await get('system/status');
      return result != null;
    } on ArrException {
      return false;
    }
  }

  /// `/qualityprofile` is identical across Radarr/Sonarr/Lidarr (same
  /// resource shape, same PUT-the-whole-object update semantics), so it
  /// lives on the shared base rather than being duplicated per client.
  Future<List<dynamic>> getQualityProfiles() async {
    final result = await get('qualityprofile');
    return result as List<dynamic>;
  }

  Future<void> updateQualityProfile(
      int id, Map<String, dynamic> updatedProfile) async {
    await put('qualityprofile/$id', body: updatedProfile);
  }

  /// Creates a new profile from a full profile body (typically an
  /// existing profile's JSON with `id` stripped and `name` changed) —
  /// the server assigns the new id. Cloning an existing profile is the
  /// supported creation path here rather than building a from-scratch
  /// quality-group picker, which would need its own deep nested editor.
  Future<Map<String, dynamic>> createQualityProfile(
      Map<String, dynamic> profile) async {
    final body = {...profile}..remove('id');
    final result = await post('qualityprofile', body: body);
    return result as Map<String, dynamic>;
  }

  Future<void> deleteQualityProfile(int id) async {
    await delete('qualityprofile/$id');
  }

  void close() => _http.close();
}
