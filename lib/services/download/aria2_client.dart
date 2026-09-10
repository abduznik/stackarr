import 'dart:convert';
import 'package:http/http.dart' as http;
import '../arr/arr_exception.dart';

/// Aria2 speaks JSON-RPC 2.0 over a single endpoint (`/jsonrpc`), not REST —
/// every call is a POST with a `method` name and positional `params`. Auth
/// is an optional `token:` prefix on the first param, set via `--rpc-secret`
/// on the aria2 daemon; [rpcSecret] may be null for daemons without one.
class Aria2Client {
  final String baseUrl;
  final String? rpcSecret;
  final http.Client _http;
  int _requestId = 0;

  Aria2Client({
    required this.baseUrl,
    this.rpcSecret,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  Uri get _uri {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$cleanBase/jsonrpc');
  }

  List<dynamic> _withAuth(List<dynamic> params) {
    if (rpcSecret == null || rpcSecret!.isEmpty) return params;
    return ['token:$rpcSecret', ...params];
  }

  Future<dynamic> _call(String method,
      [List<dynamic> params = const []]) async {
    final id = (_requestId++).toString();
    final payload = {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': _withAuth(params),
    };

    http.Response response;
    try {
      response = await _http
          .post(
            _uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ArrException.network(e);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ArrException.unexpectedStatus(response.statusCode, response.body);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded.containsKey('error')) {
      final error = decoded['error'] as Map<String, dynamic>;
      final message = error['message'] as String? ?? 'Aria2 RPC error';
      if (message.toLowerCase().contains('unauthorized')) {
        throw ArrException.unauthorized();
      }
      throw ArrException(message);
    }
    return decoded['result'];
  }

  Future<bool> checkHealth() async {
    try {
      await _call('aria2.getVersion');
      return true;
    } on ArrException {
      return false;
    }
  }

  /// Active + waiting + stopped downloads, each a raw GID-keyed status Map
  /// (keys: gid, status, totalLength, completedLength, downloadSpeed, files).
  Future<List<dynamic>> getActiveDownloads() =>
      _call('aria2.tellActive').then((r) => r as List<dynamic>);

  Future<List<dynamic>> getWaitingDownloads({int offset = 0, int num = 50}) =>
      _call('aria2.tellWaiting', [offset, num]).then((r) => r as List<dynamic>);

  Future<List<dynamic>> getStoppedDownloads({int offset = 0, int num = 50}) =>
      _call('aria2.tellStopped', [offset, num]).then((r) => r as List<dynamic>);

  Future<String> addUri(String uri, {String? downloadDir}) async {
    final result = await _call('aria2.addUri', [
      [uri],
      if (downloadDir != null) {'dir': downloadDir},
    ]);
    return result as String;
  }

  Future<void> pause(String gid) => _call('aria2.pause', [gid]);

  Future<void> unpause(String gid) => _call('aria2.unpause', [gid]);

  Future<void> remove(String gid) => _call('aria2.remove', [gid]);

  void close() => _http.close();
}
