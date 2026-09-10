class Episode {
  final int id;
  final int seriesId;
  final int seasonNumber;
  final int episodeNumber;
  final String title;
  final String? airDate;
  final bool hasFile;
  final bool monitored;
  final String? overview;

  const Episode({
    required this.id,
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.title,
    this.airDate,
    required this.hasFile,
    required this.monitored,
    this.overview,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'] as int,
      seriesId: json['seriesId'] as int? ?? 0,
      seasonNumber: json['seasonNumber'] as int? ?? 0,
      episodeNumber: json['episodeNumber'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      airDate: json['airDate'] as String?,
      hasFile: json['hasFile'] as bool? ?? false,
      monitored: json['monitored'] as bool? ?? false,
      overview: json['overview'] as String?,
    );
  }
}
