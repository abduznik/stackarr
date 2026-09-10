import 'package:flutter_test/flutter_test.dart';
import 'package:stackarr/models/calendar_entry.dart';
import 'package:stackarr/models/instance_config.dart';
import 'package:stackarr/models/service_type.dart';
import 'package:stackarr/screens/calendar/calendar_screen.dart';

void main() {
  final radarrInstance = InstanceConfig(
    id: '1',
    type: ServiceType.radarr,
    label: 'Movies',
    baseUrl: 'http://localhost:7878',
  );
  final sonarrInstance = InstanceConfig(
    id: '2',
    type: ServiceType.sonarr,
    label: 'TV',
    baseUrl: 'http://localhost:8989',
  );

  group('CalendarEntry.fromRadarr', () {
    test('prefers physicalRelease, falls back to digital then cinema', () {
      final entry = CalendarEntry.fromRadarr(radarrInstance, {
        'title': 'Dune: Part Two',
        'physicalRelease': '2024-04-16T00:00:00Z',
        'digitalRelease': '2024-03-01T00:00:00Z',
        'hasFile': false,
      });

      expect(entry.title, 'Dune: Part Two');
      expect(entry.date, DateTime.parse('2024-04-16T00:00:00Z'));
      expect(entry.hasFile, isFalse);
    });

    test('falls back to inCinemas when no release dates are set', () {
      final entry = CalendarEntry.fromRadarr(radarrInstance, {
        'title': 'New Release',
        'inCinemas': '2024-01-05T00:00:00Z',
        'hasFile': true,
      });

      expect(entry.date, DateTime.parse('2024-01-05T00:00:00Z'));
      expect(entry.hasFile, isTrue);
    });
  });

  group('CalendarEntry.fromSonarr', () {
    test('formats season/episode subtitle and pulls series title', () {
      final entry = CalendarEntry.fromSonarr(sonarrInstance, {
        'title': 'Pilot',
        'seasonNumber': 1,
        'episodeNumber': 3,
        'airDateUtc': '2024-05-10T20:00:00Z',
        'hasFile': false,
        'series': {'title': 'Breaking Bad'},
      });

      expect(entry.title, 'Breaking Bad');
      expect(entry.subtitle, 'S01E03 · Pilot');
      expect(entry.date, DateTime.parse('2024-05-10T20:00:00Z'));
    });
  });

  group('hasCalendarCapableInstance', () {
    test('true when a Radarr instance is configured', () {
      expect(hasCalendarCapableInstance([radarrInstance]), isTrue);
    });

    test('true when a Sonarr instance is configured', () {
      expect(hasCalendarCapableInstance([sonarrInstance]), isTrue);
    });

    test('false when only non-calendar services are configured', () {
      final qbt = InstanceConfig(
        id: '3',
        type: ServiceType.qbittorrent,
        label: 'Downloads',
        baseUrl: 'http://localhost:8080',
      );
      expect(hasCalendarCapableInstance([qbt]), isFalse);
    });

    test('false with no instances', () {
      expect(hasCalendarCapableInstance([]), isFalse);
    });
  });
}
