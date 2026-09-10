import 'package:flutter_test/flutter_test.dart';
import 'package:stackarr/models/episode.dart';
import 'package:stackarr/screens/tv/series_detail_screen.dart';

Episode _episode(int season, int number, {bool hasFile = false}) => Episode(
      id: season * 100 + number,
      seriesId: 1,
      seasonNumber: season,
      episodeNumber: number,
      title: 'Episode $number',
      hasFile: hasFile,
      monitored: true,
    );

void main() {
  test('groups episodes under their season number', () {
    final episodes = [
      _episode(1, 1),
      _episode(1, 2),
      _episode(2, 1),
    ];

    final grouped = groupEpisodesBySeason(episodes);

    expect(grouped.keys.toSet(), {1, 2});
    expect(grouped[1]!.length, 2);
    expect(grouped[2]!.length, 1);
  });

  test('sorts episodes within a season by episode number', () {
    final episodes = [
      _episode(1, 3),
      _episode(1, 1),
      _episode(1, 2),
    ];

    final grouped = groupEpisodesBySeason(episodes);

    expect(grouped[1]!.map((e) => e.episodeNumber), [1, 2, 3]);
  });

  test('season 0 (specials) is its own group', () {
    final episodes = [_episode(0, 1), _episode(1, 1)];

    final grouped = groupEpisodesBySeason(episodes);

    expect(grouped.containsKey(0), isTrue);
    expect(grouped[0]!.single.seasonNumber, 0);
  });

  test('empty input produces an empty map', () {
    expect(groupEpisodesBySeason([]), isEmpty);
  });
}
