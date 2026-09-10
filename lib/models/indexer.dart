class Indexer {
  final int id;
  final String name;
  final bool enable;
  final String protocol;
  final int priority;
  final int? appProfileId;
  final bool supportsRss;
  final bool supportsSearch;

  const Indexer({
    required this.id,
    required this.name,
    required this.enable,
    required this.protocol,
    required this.priority,
    this.appProfileId,
    required this.supportsRss,
    required this.supportsSearch,
  });

  factory Indexer.fromJson(Map<String, dynamic> json) {
    return Indexer(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      enable: json['enable'] as bool? ?? false,
      protocol: json['protocol'] as String? ?? 'unknown',
      priority: json['priority'] as int? ?? 0,
      appProfileId: json['appProfileId'] as int?,
      supportsRss: json['supportsRss'] as bool? ?? false,
      supportsSearch: json['supportsSearch'] as bool? ?? false,
    );
  }
}
