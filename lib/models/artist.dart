class Artist {
  final int id;
  final String? foreignArtistId;
  final String artistName;
  final String? overview;
  final String? posterUrl;
  final bool monitored;
  final String status;
  final int qualityProfileId;

  const Artist({
    required this.id,
    this.foreignArtistId,
    required this.artistName,
    this.overview,
    this.posterUrl,
    required this.monitored,
    required this.status,
    required this.qualityProfileId,
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
    return Artist(
      id: json['id'] as int,
      foreignArtistId: json['foreignArtistId'] as String?,
      artistName: json['artistName'] as String? ?? '',
      overview: json['overview'] as String?,
      posterUrl: poster,
      monitored: json['monitored'] as bool? ?? false,
      status: json['status'] as String? ?? 'unknown',
      qualityProfileId: json['qualityProfileId'] as int? ?? 0,
    );
  }
}
