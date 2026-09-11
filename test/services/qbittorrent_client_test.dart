import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:stackarr/services/download/qbittorrent_client.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  test('login sends a Referer header matching baseUrl', () async {
    // Confirmed against a real reverse-proxied qBittorrent instance:
    // without a same-origin Referer, qBittorrent's CSRF/host-header
    // protection returns 200 "Fails." with no Set-Cookie instead of an
    // auth error — the login silently does nothing rather than failing
    // loudly, so this needs a regression test.
    final mockHttp = _MockHttpClient();
    final client = QbittorrentClient(
      baseUrl: 'http://qbt.example.com:8080',
      username: 'admin',
      password: 'adminadmin',
      httpClient: mockHttp,
    );

    when(() => mockHttp.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => http.Response(
              'Ok.',
              200,
              headers: {'set-cookie': 'SID=abc123; Path=/'},
            ));

    await client.login();

    final capturedHeaders = verify(() => mockHttp.post(
          any(),
          headers: captureAny(named: 'headers'),
          body: any(named: 'body'),
        )).captured.single as Map<String, String>;

    expect(capturedHeaders['Referer'], 'http://qbt.example.com:8080');
  });

  test('login throws ArrException.unauthorized when the body is not "Ok."',
      () async {
    final mockHttp = _MockHttpClient();
    final client = QbittorrentClient(
      baseUrl: 'http://qbt.example.com:8080',
      username: 'admin',
      password: 'wrong',
      httpClient: mockHttp,
    );

    when(() => mockHttp.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => http.Response('Fails.', 200));

    expect(() => client.login(), throwsA(isA<Exception>()));
  });

  test('getTorrents GETs torrents/info with the session cookie', () async {
    final mockHttp = _MockHttpClient();
    final client = QbittorrentClient(
      baseUrl: 'http://qbt.example.com:8080',
      username: 'admin',
      password: 'adminadmin',
      httpClient: mockHttp,
    );

    when(() => mockHttp.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => http.Response(
              'Ok.',
              200,
              headers: {'set-cookie': 'SID=abc123; Path=/'},
            ));
    when(() => mockHttp.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response(
              jsonEncode([
                {'hash': 'abc', 'name': 'Test Torrent', 'progress': 0.5},
              ]),
              200,
            ));

    final torrents = await client.getTorrents();

    final capturedHeaders =
        verify(() => mockHttp.get(any(), headers: captureAny(named: 'headers')))
            .captured
            .single as Map<String, String>;
    expect(capturedHeaders['Cookie'], 'SID=abc123');
    expect(torrents, hasLength(1));
    expect((torrents.first as Map)['name'], 'Test Torrent');
  });
}
