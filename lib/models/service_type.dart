enum ServiceType {
  radarr,
  sonarr,
  lidarr,
  prowlarr,
  bazarr,
  qbittorrent,
  aria2,
  jellyseerr;

  String get label => switch (this) {
        ServiceType.radarr => 'Radarr',
        ServiceType.sonarr => 'Sonarr',
        ServiceType.lidarr => 'Lidarr',
        ServiceType.prowlarr => 'Prowlarr',
        ServiceType.bazarr => 'Bazarr',
        ServiceType.qbittorrent => 'qBittorrent',
        ServiceType.aria2 => 'Aria2',
        ServiceType.jellyseerr => 'Jellyseerr',
      };

  String get description => switch (this) {
        ServiceType.radarr => 'Movie management',
        ServiceType.sonarr => 'TV show management',
        ServiceType.lidarr => 'Music management',
        ServiceType.prowlarr => 'Indexer management',
        ServiceType.bazarr => 'Subtitle management',
        ServiceType.qbittorrent => 'Torrent downloads',
        ServiceType.aria2 => 'Download management',
        ServiceType.jellyseerr => 'Media requests',
      };

  /// Whether this service authenticates with a simple `X-Api-Key` header
  /// (the Servarr family + Bazarr + Jellyseerr) vs. a bespoke auth scheme
  /// (qBittorrent cookie auth, Aria2 optional RPC secret).
  bool get usesApiKeyHeader =>
      this != ServiceType.qbittorrent && this != ServiceType.aria2;
}
