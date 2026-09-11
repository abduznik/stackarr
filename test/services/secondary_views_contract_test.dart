import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:stackarr/services/arr/prowlarr_client.dart';
import 'package:stackarr/services/download/aria2_client.dart';
import 'package:stackarr/services/download/qbittorrent_client.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  group('ProwlarrClient.getApplications', () {
    test('GETs the applications endpoint and returns the raw list', () async {
      final mockHttp = _MockHttpClient();
      final client = ProwlarrClient(
          baseUrl: 'http://localhost:9696',
          apiKey: 'key',
          httpClient: mockHttp);

      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode([
                  {
                    'name': 'Radarr',
                    'implementationName': 'Radarr',
                    'syncLevel': 'fullSync'
                  },
                ]),
                200,
              ));

      final result = await client.getApplications();

      final capturedUri = verify(
              () => mockHttp.get(captureAny(), headers: any(named: 'headers')))
          .captured
          .single as Uri;
      expect(capturedUri.path, contains('/api/v1/applications'));
      expect(result, hasLength(1));
      expect((result.first as Map)['name'], 'Radarr');
    });
  });

  group('Aria2Client.getStoppedDownloads', () {
    test('sends aria2.tellStopped with offset/num params', () async {
      final mockHttp = _MockHttpClient();
      final client =
          Aria2Client(baseUrl: 'http://localhost:6800', httpClient: mockHttp);

      when(() => mockHttp.post(any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'))).thenAnswer((invocation) async {
        final body = jsonDecode(invocation.namedArguments[#body] as String)
            as Map<String, dynamic>;
        expect(body['method'], 'aria2.tellStopped');
        expect(body['params'], [0, 50]);
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': []}),
          200,
        );
      });

      final result = await client.getStoppedDownloads();
      expect(result, isEmpty);
    });

    test('includes the rpc secret token as the first param when set', () async {
      final mockHttp = _MockHttpClient();
      final client = Aria2Client(
          baseUrl: 'http://localhost:6800',
          rpcSecret: 'mysecret',
          httpClient: mockHttp);

      when(() => mockHttp.post(any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'))).thenAnswer((invocation) async {
        final body = jsonDecode(invocation.namedArguments[#body] as String)
            as Map<String, dynamic>;
        expect(body['params'], ['token:mysecret', 0, 50]);
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': []}),
          200,
        );
      });

      await client.getStoppedDownloads();
    });
  });

  group('QbittorrentClient transfer info and speed limits', () {
    Future<QbittorrentClient> loggedInClient(_MockHttpClient mockHttp) async {
      when(() => mockHttp.post(any(), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response(
                'Ok.',
                200,
                headers: {'set-cookie': 'SID=abc123; Path=/'},
              ));
      final client = QbittorrentClient(
        baseUrl: 'http://localhost:8080',
        username: 'admin',
        password: 'adminadmin',
        httpClient: mockHttp,
      );
      await client.login();
      return client;
    }

    test('getTransferInfo GETs transfer/info and returns parsed JSON',
        () async {
      final mockHttp = _MockHttpClient();
      final client = await loggedInClient(mockHttp);

      when(() => mockHttp.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode({'dl_info_speed': 1024, 'up_info_speed': 512}),
                200,
              ));

      final info = await client.getTransferInfo();

      final capturedUri = verify(
              () => mockHttp.get(captureAny(), headers: any(named: 'headers')))
          .captured
          .single as Uri;
      expect(capturedUri.path, contains('/api/v2/transfer/info'));
      expect(info['dl_info_speed'], 1024);
    });

    test('setSpeedLimit posts the download limit in bytes/sec', () async {
      final mockHttp = _MockHttpClient();
      final client = await loggedInClient(mockHttp);

      // Re-stub post() now that login (which also POSTs) already happened,
      // so the capture below only sees the setSpeedLimit call.
      when(() => mockHttp.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response('', 200));

      await client.setSpeedLimit(downloadKbps: 500);

      final captured = verify(() => mockHttp.post(
            captureAny(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          )).captured;
      // captured is [uri1, body1, uri2, body2, ...] across every matching
      // call this mock has ever recorded; the setSpeedLimit call is last.
      final uri = captured[captured.length - 2] as Uri;
      final body = captured.last as Map<String, String>;
      expect(uri.path, contains('/api/v2/transfer/setDownloadLimit'));
      expect(body['limit'], (500 * 1024).toString());
    });
  });
}
