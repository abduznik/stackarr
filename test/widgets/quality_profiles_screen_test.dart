import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackarr/services/arr/servarr_client.dart';
import 'package:stackarr/screens/shared/quality_profiles_screen.dart';

class _FakeServarrClient extends ServarrClient {
  List<Map<String, dynamic>> profiles;
  Map<String, dynamic>? lastUpdatedBody;
  int? lastUpdatedId;

  _FakeServarrClient(this.profiles)
      : super(baseUrl: 'http://localhost', apiKey: 'key', apiVersion: 'v3');

  @override
  Future<List<dynamic>> getQualityProfiles() async => profiles;

  @override
  Future<void> updateQualityProfile(
      int id, Map<String, dynamic> updatedProfile) async {
    lastUpdatedId = id;
    lastUpdatedBody = updatedProfile;
    profiles = profiles.map((p) => p['id'] == id ? updatedProfile : p).toList();
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

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

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

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(client.lastUpdatedBody, isNull);
  });

  testWidgets('shows empty state when there are no profiles', (tester) async {
    final client = _FakeServarrClient([]);

    await tester.pumpWidget(MaterialApp(
      home: QualityProfilesScreen(client: client),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No quality profiles found'), findsOneWidget);
  });
}
