class Season {
  final int seasonNumber;
  final bool monitored;
  final int episodeCount;
  final int episodeFileCount;

  const Season({
    required this.seasonNumber,
    required this.monitored,
    required this.episodeCount,
    required this.episodeFileCount,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    final stats = json['statistics'] as Map<String, dynamic>?;
    return Season(
      seasonNumber: json['seasonNumber'] as int? ?? 0,
      monitored: json['monitored'] as bool? ?? false,
      episodeCount: stats?['episodeCount'] as int? ?? 0,
      episodeFileCount: stats?['episodeFileCount'] as int? ?? 0,
    );
  }
}

class Series {
  final int id;
  final int? tvdbId;
  final String title;
  final int year;
  final String? overview;
  final String? posterUrl;
  final bool monitored;
  final String status;
  final int qualityProfileId;
  final List<Season> seasons;
  final List<String> genres;
  final String? network;
  final int? runtime;

  /// Sonarr nests this as ratings.value (unlike Radarr's per-provider
  /// ratings.tmdb.value) — out of 10.
  final double? rating;

  const Series({
    required this.id,
    this.tvdbId,
    required this.title,
    required this.year,
    this.overview,
    this.posterUrl,
    required this.monitored,
    required this.status,
    required this.qualityProfileId,
    required this.seasons,
    this.genres = const [],
    this.network,
    this.runtime,
    this.rating,
  });

  int get seasonCount => seasons.length;

  factory Series.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List<dynamic>?) ?? [];
    String? poster;
    for (final img in images) {
      if (img['coverType'] == 'poster') {
        poster = img['remoteUrl'] as String? ?? img['url'] as String?;
        break;
      }
    }
    final seasonsJson = (json['seasons'] as List<dynamic>?) ?? [];
    final ratings = json['ratings'] as Map<String, dynamic>?;
    return Series(
      id: json['id'] as int,
      tvdbId: json['tvdbId'] as int?,
      title: json['title'] as String,
      year: json['year'] as int? ?? 0,
      overview: json['overview'] as String?,
      posterUrl: poster,
      monitored: json['monitored'] as bool? ?? false,
      status: json['status'] as String? ?? 'unknown',
      qualityProfileId: json['qualityProfileId'] as int? ?? 0,
      seasons: seasonsJson
          .map((e) => Season.fromJson(e as Map<String, dynamic>))
          .toList(),
      genres: (json['genres'] as List<dynamic>?)?.cast<String>() ?? const [],
      network: json['network'] as String?,
      runtime: json['runtime'] as int?,
      rating: (ratings?['value'] as num?)?.toDouble(),
    );
  }
}
