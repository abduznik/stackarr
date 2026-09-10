class Movie {
  final int id;
  final String title;
  final int year;
  final String? overview;
  final String? posterUrl;
  final bool monitored;
  final bool hasFile;
  final String status;
  final double? sizeOnDisk;
  final int qualityProfileId;

  const Movie({
    required this.id,
    required this.title,
    required this.year,
    this.overview,
    this.posterUrl,
    required this.monitored,
    required this.hasFile,
    required this.status,
    this.sizeOnDisk,
    required this.qualityProfileId,
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
    return Movie(
      id: json['id'] as int,
      title: json['title'] as String,
      year: json['year'] as int? ?? 0,
      overview: json['overview'] as String?,
      posterUrl: poster,
      monitored: json['monitored'] as bool? ?? false,
      hasFile: json['hasFile'] as bool? ?? false,
      status: json['status'] as String? ?? 'unknown',
      sizeOnDisk: (json['sizeOnDisk'] as num?)?.toDouble(),
      qualityProfileId: json['qualityProfileId'] as int? ?? 0,
    );
  }
}
