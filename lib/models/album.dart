class Album {
  final int id;
  final int artistId;
  final String title;
  final String? releaseDate;
  final bool monitored;
  final bool hasFile;
  final int trackCount;

  const Album({
    required this.id,
    required this.artistId,
    required this.title,
    this.releaseDate,
    required this.monitored,
    required this.hasFile,
    required this.trackCount,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    final stats = json['statistics'] as Map<String, dynamic>?;
    final trackFileCount = stats?['trackFileCount'] as int? ?? 0;
    return Album(
      id: json['id'] as int,
      artistId: json['artistId'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      releaseDate: json['releaseDate'] as String?,
      monitored: json['monitored'] as bool? ?? false,
      hasFile: trackFileCount > 0,
      trackCount: stats?['trackCount'] as int? ?? 0,
    );
  }
}
