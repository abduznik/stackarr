import 'package:flutter_test/flutter_test.dart';
import 'package:stackarr/screens/subtitles/subtitles_screen.dart';

void main() {
  test('a wanted movie uses title with no subtitle line', () {
    final display = wantedItemDisplay({
      'title': 'Chainsaw Man - The Movie: Reze Arc',
      'missing_subtitles': [],
      'radarrId': 4,
      'sceneName': 'some.release.name',
      'tags': [],
    });

    expect(display.title, 'Chainsaw Man - The Movie: Reze Arc');
    expect(display.subtitle, isNull);
  });

  test(
      'a wanted episode uses seriesTitle and combines episode_number + episodeTitle',
      () {
    // Real shape confirmed against a live Bazarr instance: episodes use
    // camelCase episodeTitle and a "SxE"-formatted episode_number string
    // — not episode_title, which this screen originally (incorrectly)
    // assumed and which never appears in the real API response.
    final display = wantedItemDisplay({
      'seriesTitle': 'Chiikawa',
      'episode_number': '1x22',
      'episodeTitle': 'Somevania 2',
      'missing_subtitles': [
        {'name': 'English', 'code2': 'en', 'code3': 'eng'}
      ],
      'sonarrSeriesId': 1,
      'sonarrEpisodeId': 22,
      'sceneName': '[SubsPlease] Chiikawa - 22 (1080p) [C633C593]',
      'tags': [],
      'seriesType': 'anime',
    });

    expect(display.title, 'Chiikawa');
    expect(display.subtitle, '1x22 · Somevania 2');
  });

  test('an episode missing episodeTitle still shows the episode number', () {
    final display = wantedItemDisplay({
      'seriesTitle': 'Some Show',
      'episode_number': '2x05',
    });

    expect(display.subtitle, '2x05');
  });

  test('falls back to "Unknown" when neither title nor seriesTitle is present',
      () {
    final display = wantedItemDisplay({'sceneName': 'mystery.mkv'});

    expect(display.title, 'Unknown');
  });
}
