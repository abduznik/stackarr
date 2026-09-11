class Movie {
  final int id;
  final int? tmdbId;
  final String title;
  final int year;
  final String? overview;
  final String? posterUrl;
  final bool monitored;
  final bool hasFile;
  final String status;
  final double? sizeOnDisk;
  final int qualityProfileId;
  final List<String> genres;
  final int? runtime;
  final String? certification;
  final String? studio;

  /// TMDB rating out of 10, e.g. 7.8 — from ratings.tmdb.value, present
  /// on real Radarr responses even though it's easy to miss in the
  /// nested ratings object.
  final double? tmdbRating;

  const Movie({
    required this.id,
    this.tmdbId,
    required this.title,
    required this.year,
    this.overview,
    this.posterUrl,
    required this.monitored,
    required this.hasFile,
    required this.status,
    this.sizeOnDisk,
    required this.qualityProfileId,
    this.genres = const [],
    this.runtime,
    this.certification,
    this.studio,
    this.tmdbRating,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List<dynamic>?) ?? [];
    String? poster;
    for (final img in images) {
      if (img['coverType'] == 'poster') {
        poster = img['remoteUrl'] as String? ?? img['url'] as String?;
        break;
      }
    }
    final ratings = json['ratings'] as Map<String, dynamic>?;
    final tmdbRatings = ratings?['tmdb'] as Map<String, dynamic>?;
    return Movie(
      id: json['id'] as int,
      tmdbId: json['tmdbId'] as int?,
      title: json['title'] as String,
      year: json['year'] as int? ?? 0,
      overview: json['overview'] as String?,
      posterUrl: poster,
      monitored: json['monitored'] as bool? ?? false,
      hasFile: json['hasFile'] as bool? ?? false,
      status: json['status'] as String? ?? 'unknown',
      sizeOnDisk: (json['sizeOnDisk'] as num?)?.toDouble(),
      qualityProfileId: json['qualityProfileId'] as int? ?? 0,
      genres: (json['genres'] as List<dynamic>?)?.cast<String>() ?? const [],
      runtime: json['runtime'] as int?,
      certification: json['certification'] as String?,
      studio: json['studio'] as String?,
      tmdbRating: (tmdbRatings?['value'] as num?)?.toDouble(),
    );
  }
}
