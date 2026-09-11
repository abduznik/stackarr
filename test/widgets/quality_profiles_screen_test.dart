import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackarr/services/arr/servarr_client.dart';
import 'package:stackarr/screens/shared/quality_profiles_screen.dart';

class _FakeServarrClient extends ServarrClient {
  List<Map<String, dynamic>> profiles;
  Map<String, dynamic>? lastUpdatedBody;
  int? lastUpdatedId;
  Map<String, dynamic>? lastCreatedBody;
  int? lastDeletedId;
  int _nextId;

  _FakeServarrClient(this.profiles, {int nextId = 100})
      : _nextId = nextId,
        super(baseUrl: 'http://localhost', apiKey: 'key', apiVersion: 'v3');

  @override
  Future<List<dynamic>> getQualityProfiles() async => profiles;

  @override
  Future<void> updateQualityProfile(
      int id, Map<String, dynamic> updatedProfile) async {
    lastUpdatedId = id;
    lastUpdatedBody = updatedProfile;
    profiles = profiles.map((p) => p['id'] == id ? updatedProfile : p).toList();
  }

  @override
  Future<Map<String, dynamic>> createQualityProfile(
      Map<String, dynamic> profile) async {
    lastCreatedBody = profile;
    final created = {...profile, 'id': _nextId++};
    profiles = [...profiles, created];
    return created;
  }

  @override
  Future<void> deleteQualityProfile(int id) async {
    lastDeletedId = id;
    profiles = profiles.where((p) => p['id'] != id).toList();
  }
}

Map<String, dynamic> _sampleProfile({
  int id = 1,
  String name = 'HD-1080p',
  bool upgradeAllowed = true,
  int cutoff = 7,
}) =>
    {
      'id': id,
      'name': name,
      'upgradeAllowed': upgradeAllowed,
      'cutoff': cutoff,
      'items': [
        {
          'quality': {'id': 4, 'name': 'HDTV-720p'},
          'allowed': false,
        },
        {
          'quality': {'id': 7, 'name': 'Bluray-1080p'},
          'allowed': true,
        },
      ],
    };

Future<void> _openMenuAndSelect(WidgetTester tester, String menuLabel) async {
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(menuLabel).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists profiles with allowed count and cutoff summary',
      (tester) async {
    final client = _FakeServarrClient([_sampleProfile()]);

    await tester.pumpWidget(MaterialApp(
      home: QualityProfilesScreen(client: client),
    ));
    await tester.pumpAndSettle();

    expect(find.text('HD-1080p'), findsOneWidget);
    expect(find.textContaining('1 allowed quality(ies)'), findsOneWidget);
    expect(find.textContaining('upgrade until Bluray-1080p'), findsOneWidget);
  });

  testWidgets('shows "upgrades disabled" when upgradeAllowed is false',
      (tester) async {
    final client = _FakeServarrClient([_sampleProfile(upgradeAllowed: false)]);

    await tester.pumpWidget(MaterialApp(
      home: QualityProfilesScreen(client: client),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('upgrades disabled'), findsOneWidget);
  });

  testWidgets('editing a profile renames it and saves via updateQualityProfile',
      (tester) async {
    final client = _FakeServarrClient([_sampleProfile()]);

    await tester.pumpWidget(MaterialApp(
      home: QualityProfilesScreen(client: client),
    ));
    await tester.pumpAndSettle();

    await _openMenuAndSelect(tester, 'Edit');

    expect(find.text('Edit quality profile'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Renamed Profile');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(client.lastUpdatedId, 1);
    expect(client.lastUpdatedBody?['name'], 'Renamed Profile');
    expect(client.profiles.first['name'], 'Renamed Profile');
    expect(find.text('Renamed Profile'), findsOneWidget);
  });

  testWidgets('cancelling the edit dialog does not call updateQualityProfile',
      (tester) async {
    final client = _FakeServarrClient([_sampleProfile()]);

    await tester.pumpWidget(MaterialApp(
      home: QualityProfilesScreen(client: client),
    ));
    await tester.pumpAndSettle();

    await _openMenuAndSelect(tester, 'Edit');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(client.lastUpdatedBody, isNull);
  });

  testWidgets(
      'duplicating a profile creates a new one via createQualityProfile',
      (tester) async {
    final client = _FakeServarrClient([_sampleProfile()]);

    await tester.pumpWidget(MaterialApp(
      home: QualityProfilesScreen(client: client),
    ));
    await tester.pumpAndSettle();

    await _openMenuAndSelect(tester, 'Duplicate');

    expect(find.text('Duplicate profile'), findsOneWidget);
    expect(find.text('HD-1080p (copy)'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    // The screen passes the full profile body (id included, per the real
    // ServarrClient.createQualityProfile's contract of stripping it);
    // this fake bypasses that stripping since it overrides the method
    // entirely, so it's asserting what the screen sends, not what a real
    // server call would ultimately post.
    expect(client.lastCreatedBody?['name'], 'HD-1080p (copy)');
    expect(find.text('HD-1080p (copy)'), findsOneWidget);
    expect(client.profiles.length, 2);
  });

  testWidgets('cancelling duplicate does not call createQualityProfile',
      (tester) async {
    final client = _FakeServarrClient([_sampleProfile()]);

    await tester.pumpWidget(MaterialApp(
      home: QualityProfilesScreen(client: client),
    ));
    await tester.pumpAndSettle();

    await _openMenuAndSelect(tester, 'Duplicate');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(client.lastCreatedBody, isNull);
    expect(client.profiles.length, 1);
  });

  testWidgets('deleting a profile confirms then calls deleteQualityProfile',
      (tester) async {
    final client = _FakeServarrClient([_sampleProfile()]);

    await tester.pumpWidget(MaterialApp(
      home: QualityProfilesScreen(client: client),
    ));
    await tester.pumpAndSettle();

    await _openMenuAndSelect(tester, 'Delete');

    expect(find.text('Delete "HD-1080p"?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
    await tester.pumpAndSettle();

    expect(client.lastDeletedId, 1);
    expect(client.profiles, isEmpty);
    expect(find.text('HD-1080p'), findsNothing);
  });

  testWidgets('cancelling delete does not call deleteQualityProfile',
      (tester) async {
    final client = _FakeServarrClient([_sampleProfile()]);

    await tester.pumpWidget(MaterialApp(
      home: QualityProfilesScreen(client: client),
    ));
    await tester.pumpAndSettle();

    await _openMenuAndSelect(tester, 'Delete');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(client.lastDeletedId, isNull);
    expect(find.text('HD-1080p'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no profiles', (tester) async {
    final client = _FakeServarrClient([]);

    await tester.pumpWidget(MaterialApp(
      home: QualityProfilesScreen(client: client),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('No quality profiles found'), findsOneWidget);
  });
}
