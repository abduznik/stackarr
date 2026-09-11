import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackarr/screens/shared/library_search_bar.dart';

void main() {
  testWidgets('starts collapsed as a search icon', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LibrarySearchBar(onQueryChanged: (_) {})),
    ));

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('tapping the icon expands into a text field', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LibrarySearchBar(onQueryChanged: (_) {})),
    ));

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('typing calls onQueryChanged with the current text',
      (tester) async {
    String? lastQuery;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: LibrarySearchBar(onQueryChanged: (q) => lastQuery = q)),
    ));

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'matrix');

    expect(lastQuery, 'matrix');
  });

  testWidgets('tapping close collapses back and clears the query',
      (tester) async {
    String? lastQuery = 'unset';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: LibrarySearchBar(onQueryChanged: (q) => lastQuery = q)),
    ));

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'matrix');

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(lastQuery, '');
  });
}
