import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackarr/models/movie.dart';
import 'package:stackarr/screens/movies/movie_detail_screen.dart';
import 'package:stackarr/services/arr/radarr_client.dart';

class _FakeRadarrClient extends RadarrClient {
  Movie movie;
  bool? lastMonitoredSet;
  int? lastSearchedId;
  int? lastDeletedId;

  _FakeRadarrClient(this.movie)
      : super(baseUrl: 'http://localhost:7878', apiKey: 'key');

  @override
  Future<void> setMonitored(int id, bool monitored) async {
    lastMonitoredSet = monitored;
    movie = Movie(
      id: movie.id,
      tmdbId: movie.tmdbId,
      title: movie.title,
      year: movie.year,
      overview: movie.overview,
      posterUrl: movie.posterUrl,
      monitored: monitored,
      hasFile: movie.hasFile,
      status: movie.status,
      sizeOnDisk: movie.sizeOnDisk,
      qualityProfileId: movie.qualityProfileId,
      genres: movie.genres,
      runtime: movie.runtime,
      certification: movie.certification,
      studio: movie.studio,
      tmdbRating: movie.tmdbRating,
    );
  }

  @override
  Future<Movie> getMovie(int id) async => movie;

  @override
  Future<void> searchMovie(int id) async {
    lastSearchedId = id;
  }

  @override
  Future<void> deleteMovie(int id, {bool deleteFiles = false}) async {
    lastDeletedId = id;
  }
}

const _sampleMovie = Movie(
  id: 1,
  tmdbId: 603,
  title: 'The Matrix',
  year: 1999,
  overview: 'A hacker discovers the truth.',
  monitored: true,
  hasFile: true,
  status: 'released',
  qualityProfileId: 1,
  genres: ['Action', 'Sci-Fi'],
  runtime: 136,
  certification: 'R',
  studio: 'Warner Bros.',
  tmdbRating: 8.2,
  sizeOnDisk: 2147483648, // 2 GB
);

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('shows metadata: title, overview, genres, rating',
      (tester) async {
    final client = _FakeRadarrClient(_sampleMovie);

    await tester.pumpWidget(_wrap(MovieDetailScreen(
      client: client,
      movie: _sampleMovie,
      onChanged: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('The Matrix'), findsWidgets);
    expect(find.text('A hacker discovers the truth.'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);
    expect(find.text('Sci-Fi'), findsOneWidget);
    expect(find.text('8.2'), findsOneWidget);
    expect(find.textContaining('1999'), findsOneWidget);
  });

  testWidgets('shows downloaded state with formatted size', (tester) async {
    final client = _FakeRadarrClient(_sampleMovie);

    await tester.pumpWidget(_wrap(MovieDetailScreen(
      client: client,
      movie: _sampleMovie,
      onChanged: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.text('2.00 GB'), findsOneWidget);
  });

  testWidgets('toggling monitored calls setMonitored and refreshes',
      (tester) async {
    var changed = false;
    final client = _FakeRadarrClient(_sampleMovie);

    await tester.pumpWidget(_wrap(MovieDetailScreen(
      client: client,
      movie: _sampleMovie,
      onChanged: () => changed = true,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(client.lastMonitoredSet, false);
    expect(changed, isTrue);
  });

  testWidgets('search now calls searchMovie with the movie id', (tester) async {
    final client = _FakeRadarrClient(_sampleMovie);

    await tester.pumpWidget(_wrap(MovieDetailScreen(
      client: client,
      movie: _sampleMovie,
      onChanged: () {},
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search now'));
    await tester.pumpAndSettle();

    expect(client.lastSearchedId, 1);
    expect(find.textContaining('Searching for'), findsOneWidget);
  });

  testWidgets('delete confirms then calls deleteMovie and pops',
      (tester) async {
    var changed = false;
    final client = _FakeRadarrClient(_sampleMovie);

    await tester.pumpWidget(_wrap(Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => MovieDetailScreen(
          client: client,
          movie: _sampleMovie,
          onChanged: () => changed = true,
        ),
      ),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete "The Matrix"?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(client.lastDeletedId, 1);
    expect(changed, isTrue);
  });
}
