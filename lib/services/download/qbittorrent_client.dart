import 'dart:convert';
import 'package:http/http.dart' as http;
import '../arr/arr_exception.dart';

/// qBittorrent's Web API (v2) authenticates via a login POST that returns a
/// `SID` session cookie — no API key at all. Every subsequent request must
/// carry that cookie, and cookies expire, so [login] is called lazily
/// before requests and retried once on a 403.
class QbittorrentClient {
  final String baseUrl;
  final String username;
  final String password;
  final http.Client _http;

  String? _sessionCookie;

  QbittorrentClient({
    required this.baseUrl,
    required this.username,
    required this.password,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$cleanBase/api/v2/$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Future<void> login() async {
    http.Response response;
    try {
      response = await _http.post(
        _uri('auth/login'),
        body: {'username': username, 'password': password},
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ArrException.network(e);
    }
    if (response.body.trim() != 'Ok.') {
      throw ArrException.unauthorized();
    }
    final setCookie = response.headers['set-cookie'];
    if (setCookie == null) throw ArrException.unauthorized();
    _sessionCookie = setCookie.split(';').first;
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? formBody,
    bool retried = false,
  }) async {
    if (_sessionCookie == null) await login();

    final headers = <String, String>{
      if (_sessionCookie != null) 'Cookie': _sessionCookie!,
    };

    http.Response response;
    try {
      final uri = _uri(path, query);
      response = await (method == 'POST'
              ? _http.post(uri, headers: headers, body: formBody)
              : _http.get(uri, headers: headers))
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ArrException.network(e);
    }

    if (response.statusCode == 403 && !retried) {
      _sessionCookie = null;
      return _request(method, path,
          query: query, formBody: formBody, retried: true);
    }
    if (response.statusCode == 403) throw ArrException.unauthorized();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ArrException.unexpectedStatus(response.statusCode, response.body);
    }
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body;
    }
  }

  Future<bool> checkHealth() async {
    try {
      await login();
      return true;
    } on ArrException {
      return false;
    }
  }

  /// Raw torrent list — each entry a Map with keys like hash, name,
  /// progress, dlspeed, upspeed, state, size, eta.
  Future<List<dynamic>> getTorrents({String? filter}) async {
    final result = await _request('GET', 'torrents/info',
        query: filter != null ? {'filter': filter} : null);
    return result as List<dynamic>;
  }

  Future<void> pauseTorrents(List<String> hashes) async {
    await _request('POST', 'torrents/pause',
        formBody: {'hashes': hashes.join('|')});
  }

  Future<void> resumeTorrents(List<String> hashes) async {
    await _request('POST', 'torrents/resume',
        formBody: {'hashes': hashes.join('|')});
  }

  Future<void> deleteTorrents(List<String> hashes,
      {bool deleteFiles = false}) async {
    await _request('POST', 'torrents/delete', formBody: {
      'hashes': hashes.join('|'),
      'deleteFiles': deleteFiles.toString(),
    });
  }

  Future<void> setSpeedLimit({int? downloadKbps, int? uploadKbps}) async {
    if (downloadKbps != null) {
      await _request('POST', 'transfer/setDownloadLimit',
          formBody: {'limit': (downloadKbps * 1024).toString()});
    }
    if (uploadKbps != null) {
      await _request('POST', 'transfer/setUploadLimit',
          formBody: {'limit': (uploadKbps * 1024).toString()});
    }
  }

  Future<Map<String, dynamic>> getTransferInfo() async {
    final result = await _request('GET', 'transfer/info');
    return result as Map<String, dynamic>;
  }

  void close() => _http.close();
}
