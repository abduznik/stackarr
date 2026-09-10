import 'package:flutter_test/flutter_test.dart';
import 'package:stackarr/models/quality_profile.dart';

void main() {
  final sampleJson = {
    'id': 1,
    'name': 'HD-1080p',
    'upgradeAllowed': true,
    'cutoff': 7,
    'items': [
      {
        'quality': {'id': 4, 'name': 'HDTV-720p'},
        'allowed': false,
      },
      {
        'quality': {'id': 7, 'name': 'Bluray-1080p'},
        'allowed': true,
      },
      {
        'name': 'WEB 1080p',
        'items': [
          {
            'quality': {'id': 9, 'name': 'WEBDL-1080p'},
            'allowed': true,
          },
        ],
        'allowed': true,
      },
    ],
  };

  test('parses top-level fields and flattens items', () {
    final profile = QualityProfile.fromJson(sampleJson);

    expect(profile.id, 1);
    expect(profile.name, 'HD-1080p');
    expect(profile.upgradeAllowed, isTrue);
    expect(profile.cutoff, 7);
    expect(profile.items.length, 3);
  });

  test('cutoffName resolves the quality name matching the cutoff id', () {
    final profile = QualityProfile.fromJson(sampleJson);

    expect(profile.cutoffName, 'Bluray-1080p');
  });

  test('cutoffName is null when no item matches the cutoff id', () {
    final profile = QualityProfile.fromJson({
      ...sampleJson,
      'cutoff': 999,
    });

    expect(profile.cutoffName, isNull);
  });

  test('a group item without a quality id falls back to its own name', () {
    final profile = QualityProfile.fromJson(sampleJson);

    final group = profile.items.firstWhere((i) => i.name == 'WEB 1080p');
    expect(group.qualityId, isNull);
    expect(group.allowed, isTrue);
  });

  test('toUpdatedJson overrides only the given fields, preserving the rest',
      () {
    final profile = QualityProfile.fromJson(sampleJson);

    final updated =
        profile.toUpdatedJson(name: 'Renamed', upgradeAllowed: false);

    expect(updated['name'], 'Renamed');
    expect(updated['upgradeAllowed'], isFalse);
    expect(updated['cutoff'], 7); // unchanged
    expect(updated['items'], sampleJson['items']); // preserved untouched
  });

  test('toUpdatedJson with no overrides returns an equivalent copy', () {
    final profile = QualityProfile.fromJson(sampleJson);

    final updated = profile.toUpdatedJson();

    expect(updated, sampleJson);
  });
}
