import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackarr/screens/shared/add_media_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  final qualityProfiles = [
    {'id': 1, 'name': 'HD-1080p'},
  ];
  final rootFolders = [
    {'path': '/movies'},
  ];

  testWidgets('shows a prompt before any search is run', (tester) async {
    await tester.pumpWidget(_wrap(AddMediaScreen(
      serviceLabel: 'Radarr',
      onSearch: (term) async => [],
      onLoadQualityProfiles: () async => qualityProfiles,
      onLoadRootFolders: () async => rootFolders,
      onAdd: ({
        required lookupResult,
        required qualityProfileId,
        required rootFolderPath,
        required monitored,
        required searchOnAdd,
      }) async {},
      titleOf: (r) => r['title'] as String,
      posterUrlOf: (r) => null,
      alreadyAdded: (r) => false,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Search to find something to add'), findsOneWidget);
  });

  testWidgets('typing a search term and submitting shows results',
      (tester) async {
    await tester.pumpWidget(_wrap(AddMediaScreen(
      serviceLabel: 'Radarr',
      onSearch: (term) async => [
        {'title': 'The Matrix', 'year': 1999, 'tmdbId': 603},
      ],
      onLoadQualityProfiles: () async => qualityProfiles,
      onLoadRootFolders: () async => rootFolders,
      onAdd: ({
        required lookupResult,
        required qualityProfileId,
        required rootFolderPath,
        required monitored,
        required searchOnAdd,
      }) async {},
      titleOf: (r) => '${r['title']} (${r['year']})',
      posterUrlOf: (r) => null,
      alreadyAdded: (r) => false,
    )));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'matrix');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('The Matrix (1999)'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add'), findsOneWidget);
  });

  testWidgets('results already in the library show "In library" instead of Add',
      (tester) async {
    await tester.pumpWidget(_wrap(AddMediaScreen(
      serviceLabel: 'Radarr',
      onSearch: (term) async => [
        {'title': 'The Matrix', 'year': 1999, 'tmdbId': 603},
      ],
      onLoadQualityProfiles: () async => qualityProfiles,
      onLoadRootFolders: () async => rootFolders,
      onAdd: ({
        required lookupResult,
        required qualityProfileId,
        required rootFolderPath,
        required monitored,
        required searchOnAdd,
      }) async {},
      titleOf: (r) => r['title'] as String,
      posterUrlOf: (r) => null,
      alreadyAdded: (r) => true,
    )));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'matrix');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('In library'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add'), findsNothing);
  });

  testWidgets('tapping Add opens the profile/folder dialog and calls onAdd',
      (tester) async {
    Map<String, dynamic>? addedResult;
    int? addedProfileId;
    String? addedRootFolder;

    await tester.pumpWidget(_wrap(AddMediaScreen(
      serviceLabel: 'Radarr',
      onSearch: (term) async => [
        {'title': 'The Matrix', 'year': 1999, 'tmdbId': 603},
      ],
      onLoadQualityProfiles: () async => qualityProfiles,
      onLoadRootFolders: () async => rootFolders,
      onAdd: ({
        required lookupResult,
        required qualityProfileId,
        required rootFolderPath,
        required monitored,
        required searchOnAdd,
      }) async {
        addedResult = lookupResult;
        addedProfileId = qualityProfileId;
        addedRootFolder = rootFolderPath;
      },
      titleOf: (r) => r['title'] as String,
      posterUrlOf: (r) => null,
      alreadyAdded: (r) => false,
    )));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'matrix');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add "The Matrix"'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add').last);
    await tester.pumpAndSettle();

    expect(addedResult?['title'], 'The Matrix');
    expect(addedProfileId, 1);
    expect(addedRootFolder, '/movies');
    expect(find.text('Added "The Matrix"'), findsOneWidget);
  });
}
