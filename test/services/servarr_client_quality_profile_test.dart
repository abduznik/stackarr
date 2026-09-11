import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:stackarr/services/arr/servarr_client.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _TestServarrClient extends ServarrClient {
  _TestServarrClient({required http.Client httpClient})
      : super(
          baseUrl: 'http://localhost:7878',
          apiKey: 'key',
          apiVersion: 'v3',
          httpClient: httpClient,
        );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  test('createQualityProfile strips the id field before POSTing', () async {
    final mockHttp = _MockHttpClient();
    final client = _TestServarrClient(httpClient: mockHttp);

    when(() => mockHttp.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => http.Response(
              jsonEncode({'id': 42, 'name': 'Cloned'}),
              201,
            ));

    await client.createQualityProfile({
      'id': 1,
      'name': 'Cloned',
      'items': [],
    });

    final captured = verify(() => mockHttp.post(
          any(),
          headers: any(named: 'headers'),
          body: captureAny(named: 'body'),
        )).captured;

    final sentBody =
        jsonDecode(captured.single as String) as Map<String, dynamic>;
    expect(sentBody.containsKey('id'), isFalse);
    expect(sentBody['name'], 'Cloned');
  });

  test('createQualityProfile posts to the qualityprofile endpoint', () async {
    final mockHttp = _MockHttpClient();
    final client = _TestServarrClient(httpClient: mockHttp);

    when(() => mockHttp.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => http.Response(
              jsonEncode({'id': 42, 'name': 'Cloned'}),
              201,
            ));

    await client.createQualityProfile({'id': 1, 'name': 'Cloned'});

    final capturedUri = verify(() => mockHttp.post(captureAny(),
        headers: any(named: 'headers'),
        body: any(named: 'body'))).captured.single as Uri;
    expect(capturedUri.path, contains('/api/v3/qualityprofile'));
  });

  test('deleteQualityProfile sends DELETE to the profile-specific path',
      () async {
    final mockHttp = _MockHttpClient();
    final client = _TestServarrClient(httpClient: mockHttp);

    when(() => mockHttp.delete(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response('', 200));

    await client.deleteQualityProfile(5);

    final capturedUri = verify(
            () => mockHttp.delete(captureAny(), headers: any(named: 'headers')))
        .captured
        .single as Uri;
    expect(capturedUri.path, contains('/api/v3/qualityprofile/5'));
  });
}
