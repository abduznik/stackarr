import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stackarr/models/instance_config.dart';
import 'package:stackarr/models/series.dart';
import 'package:stackarr/models/service_type.dart';
import 'package:stackarr/screens/tv/series_detail_screen.dart';

void main() {
  final instance = InstanceConfig(
    id: '1',
    type: ServiceType.sonarr,
    label: 'TV',
    baseUrl: 'http://localhost:8989',
  );
  const series = Series(
    id: 42,
    tvdbId: 100,
    title: 'Breaking Bad',
    year: 2008,
    monitored: true,
    status: 'continuing',
    qualityProfileId: 1,
    seasons: [],
  );

  testWidgets('renders the app bar with series title and search action',
      (tester) async {
    // The episode list itself needs a live SonarrClient (no DI seam on this
    // screen yet), so this only exercises the screen shell before the
    // network call resolves; season/episode grouping is unit-tested
    // separately in test/services/group_episodes_by_season_test.dart.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SeriesDetailScreen(instance: instance, series: series),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsWidgets);
  });
}
