class Artist {
  final int id;
  final String? foreignArtistId;
  final String artistName;
  final String? overview;
  final String? posterUrl;
  final bool monitored;
  final String status;
  final int qualityProfileId;
  final List<String> genres;
  final String? disambiguation;
  final double? rating;

  const Artist({
    required this.id,
    this.foreignArtistId,
    required this.artistName,
    this.overview,
    this.posterUrl,
    required this.monitored,
    required this.status,
    required this.qualityProfileId,
    this.genres = const [],
    this.disambiguation,
    this.rating,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List<dynamic>?) ?? [];
    String? poster;
    for (final img in images) {
      if (img['coverType'] == 'poster') {
        poster = img['remoteUrl'] as String? ?? img['url'] as String?;
        break;
      }
    }
    final ratings = json['ratings'] as Map<String, dynamic>?;
    return Artist(
      id: json['id'] as int,
      foreignArtistId: json['foreignArtistId'] as String?,
      artistName: json['artistName'] as String? ?? '',
      overview: json['overview'] as String?,
      posterUrl: poster,
      monitored: json['monitored'] as bool? ?? false,
      status: json['status'] as String? ?? 'unknown',
      qualityProfileId: json['qualityProfileId'] as int? ?? 0,
      genres: (json['genres'] as List<dynamic>?)?.cast<String>() ?? const [],
      disambiguation: json['disambiguation'] as String?,
      rating: (ratings?['value'] as num?)?.toDouble(),
    );
  }
}
