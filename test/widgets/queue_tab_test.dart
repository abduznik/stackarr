import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackarr/screens/shared/queue_tab.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows empty state when the queue has no records',
      (tester) async {
    await tester.pumpWidget(_wrap(QueueTab(onLoadQueue: () async => [])));
    await tester.pumpAndSettle();

    expect(find.text('Queue is empty'), findsOneWidget);
  });

  testWidgets('renders queue records with computed progress', (tester) async {
    await tester.pumpWidget(_wrap(QueueTab(
        onLoadQueue: () async => [
              {
                'title': 'Some.Movie.2024.1080p',
                'size': 1000.0,
                'sizeleft': 250.0,
                'status': 'downloading',
                'timeleft': '00:10:00',
              },
            ])));
    await tester.pumpAndSettle();

    expect(find.text('Some.Movie.2024.1080p'), findsOneWidget);
    expect(find.text('75% · downloading · 00:10:00'), findsOneWidget);
  });

  testWidgets('shows an error message when loading fails', (tester) async {
    await tester.pumpWidget(
        _wrap(QueueTab(onLoadQueue: () async => throw Exception('boom'))));
    await tester.pumpAndSettle();

    expect(find.textContaining('Error:'), findsOneWidget);
  });
}
