import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:stackarr/screens/requests/discover_screen.dart';
import 'package:stackarr/services/requests/jellyseerr_client.dart';

class _FakeJellyseerrClient extends JellyseerrClient {
  List<dynamic> Function(String term)? onSearch;
  Map<String, dynamic>? lastRequestBody;

  _FakeJellyseerrClient({this.onSearch})
      : super(baseUrl: 'http://localhost:5055', apiKey: 'key');

  @override
  Future<List<dynamic>> searchMedia(String query) async =>
      onSearch?.call(query) ?? [];

  @override
  Future<Map<String, dynamic>> requestMedia({
    required int mediaId,
    required String mediaType,
    List<int>? seasons,
  }) async {
    lastRequestBody = {
      'mediaId': mediaId,
      'mediaType': mediaType,
      if (seasons != null) 'seasons': seasons,
    };
    return lastRequestBody!;
  }
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows a prompt before any search is run', (tester) async {
    final client = _FakeJellyseerrClient();

    await tester.pumpWidget(_wrap(DiscoverScreen(
      client: client,
      onRequestSubmitted: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Search to find something to request'), findsOneWidget);
  });

  testWidgets('searching shows results with title', (tester) async {
    final client = _FakeJellyseerrClient(
        onSearch: (term) => [
              {
                'id': 603,
                'title': 'The Matrix',
                'mediaType': 'movie',
              },
            ]);

    await tester.pumpWidget(_wrap(DiscoverScreen(
      client: client,
      onRequestSubmitted: () {},
    )));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'matrix');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('The Matrix'), findsOneWidget);
  });

  testWidgets(
      'a result with mediaInfo shows Requested instead of an add button',
      (tester) async {
    final client = _FakeJellyseerrClient(
        onSearch: (term) => [
              {
                'id': 603,
                'title': 'The Matrix',
                'mediaType': 'movie',
                'mediaInfo': {'status': 3},
              },
            ]);

    await tester.pumpWidget(_wrap(DiscoverScreen(
      client: client,
      onRequestSubmitted: () {},
    )));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'matrix');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Requested'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets(
      'tapping request calls requestMedia and notifies onRequestSubmitted',
      (tester) async {
    var submitted = false;
    final client = _FakeJellyseerrClient(
        onSearch: (term) => [
              {
                'id': 603,
                'title': 'The Matrix',
                'mediaType': 'movie',
              },
            ]);

    await tester.pumpWidget(_wrap(DiscoverScreen(
      client: client,
      onRequestSubmitted: () => submitted = true,
    )));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'matrix');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(client.lastRequestBody, {'mediaId': 603, 'mediaType': 'movie'});
    expect(submitted, isTrue);
    expect(find.text('Requested "The Matrix"'), findsOneWidget);
  });

  testWidgets('tv results are requested with mediaType tv', (tester) async {
    final client = _FakeJellyseerrClient(
        onSearch: (term) => [
              {
                'id': 1396,
                'name': 'Breaking Bad',
                'mediaType': 'tv',
              },
            ]);

    await tester.pumpWidget(_wrap(DiscoverScreen(
      client: client,
      onRequestSubmitted: () {},
    )));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'breaking');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Breaking Bad'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(client.lastRequestBody?['mediaType'], 'tv');
  });

  testWidgets('an error during search is shown', (tester) async {
    final client = _FakeJellyseerrClient();
    client.onSearch = (term) => throw http.ClientException('boom');

    await tester.pumpWidget(_wrap(DiscoverScreen(
      client: client,
      onRequestSubmitted: () {},
    )));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'x');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.textContaining('boom'), findsOneWidget);
  });
}
