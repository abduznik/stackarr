import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackarr/screens/requests/request_detail_screen.dart';
import 'package:stackarr/services/requests/jellyseerr_client.dart';

class _FakeJellyseerrClient extends JellyseerrClient {
  Map<String, dynamic> Function(int tmdbId, String mediaType)? onGetDetails;
  int? lastRespondedId;
  String? lastRespondedAction;

  _FakeJellyseerrClient({this.onGetDetails})
      : super(baseUrl: 'http://localhost:5055', apiKey: 'key');

  @override
  Future<Map<String, dynamic>> getMediaDetails({
    required int tmdbId,
    required String mediaType,
  }) async {
    return onGetDetails?.call(tmdbId, mediaType) ?? {};
  }

  @override
  Future<void> updateRequestStatus(int requestId, String status) async {
    lastRespondedId = requestId;
    lastRespondedAction = status;
  }
}

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  final pendingRequest = {
    'id': 42,
    'status': 1,
    'media': {'tmdbId': 603, 'mediaType': 'movie'},
  };

  testWidgets('fetches real title/overview/genres via getMediaDetails',
      (tester) async {
    final client = _FakeJellyseerrClient(
      onGetDetails: (tmdbId, mediaType) => {
        'title': 'The Matrix',
        'overview': 'A hacker discovers the truth.',
        'posterPath': '/poster.jpg',
        'voteAverage': 8.2,
        'genres': [
          {'name': 'Action'},
          {'name': 'Sci-Fi'},
        ],
      },
    );

    await tester.pumpWidget(_wrap(RequestDetailScreen(
      client: client,
      request: pendingRequest,
      onChanged: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('The Matrix'), findsOneWidget);
    expect(find.text('A hacker discovers the truth.'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);
    expect(find.text('Sci-Fi'), findsOneWidget);
    expect(find.text('8.2'), findsOneWidget);
  });

  testWidgets('falls back to Request #id when details are unavailable',
      (tester) async {
    final client = _FakeJellyseerrClient(onGetDetails: (t, m) => {});

    await tester.pumpWidget(_wrap(RequestDetailScreen(
      client: client,
      request: pendingRequest,
      onChanged: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Request #42'), findsOneWidget);
  });

  testWidgets('pending requests show Approve/Decline actions', (tester) async {
    final client = _FakeJellyseerrClient(onGetDetails: (t, m) => {});

    await tester.pumpWidget(_wrap(RequestDetailScreen(
      client: client,
      request: pendingRequest,
      onChanged: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });

  testWidgets('already-approved requests hide Approve/Decline', (tester) async {
    final approvedRequest = {
      'id': 42,
      'status': 2,
      'media': {'tmdbId': 603, 'mediaType': 'movie'},
    };
    final client = _FakeJellyseerrClient(onGetDetails: (t, m) => {});

    await tester.pumpWidget(_wrap(RequestDetailScreen(
      client: client,
      request: approvedRequest,
      onChanged: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Approve'), findsNothing);
    expect(find.text('Decline'), findsNothing);
  });

  testWidgets('tapping Approve calls updateRequestStatus and pops',
      (tester) async {
    var changed = false;
    final client = _FakeJellyseerrClient(onGetDetails: (t, m) => {});

    await tester.pumpWidget(_wrap(Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => RequestDetailScreen(
          client: client,
          request: pendingRequest,
          onChanged: () => changed = true,
        ),
      ),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(client.lastRespondedId, 42);
    expect(client.lastRespondedAction, 'approve');
    expect(changed, isTrue);
  });
}
