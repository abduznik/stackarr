/// One allowed-quality row within a profile — either a single quality
/// (e.g. "Bluray-1080p") or a named group containing several qualities
/// (e.g. "WEB 1080p" grouping WEBDL-1080p/WEBRip-1080p). Servarr represents
/// both shapes in the same `items` array, distinguished by whether
/// `quality` or a nested `items` list is present.
class QualityItem {
  final int? qualityId;
  final String name;
  final bool allowed;

  const QualityItem({
    required this.qualityId,
    required this.name,
    required this.allowed,
  });

  factory QualityItem.fromJson(Map<String, dynamic> json) {
    final quality = json['quality'] as Map<String, dynamic>?;
    return QualityItem(
      qualityId: quality?['id'] as int?,
      name: quality?['name'] as String? ?? json['name'] as String? ?? 'Unknown',
      allowed: json['allowed'] as bool? ?? false,
    );
  }
}

/// A Radarr/Sonarr/Lidarr quality profile. [rawJson] is retained so edits
/// can be merged back into the exact shape the server expects on PUT
/// without this app needing to reconstruct the full nested structure.
class QualityProfile {
  final int id;
  final String name;
  final bool upgradeAllowed;
  final int cutoff;
  final List<QualityItem> items;
  final Map<String, dynamic> rawJson;

  const QualityProfile({
    required this.id,
    required this.name,
    required this.upgradeAllowed,
    required this.cutoff,
    required this.items,
    required this.rawJson,
  });

  /// The quality name the cutoff id refers to, for display.
  String? get cutoffName {
    for (final item in items) {
      if (item.qualityId == cutoff) return item.name;
    }
    return null;
  }

  factory QualityProfile.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List<dynamic>?) ?? [];
    return QualityProfile(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Unknown',
      upgradeAllowed: json['upgradeAllowed'] as bool? ?? false,
      cutoff: json['cutoff'] as int? ?? 0,
      items: itemsJson
          .map((e) => QualityItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      rawJson: json,
    );
  }

  /// Produces a PUT-ready body with [name]/[upgradeAllowed]/[cutoff]
  /// overridden but every other field (the full items structure, id,
  /// etc.) preserved exactly as the server sent it.
  Map<String, dynamic> toUpdatedJson({
    String? name,
    bool? upgradeAllowed,
    int? cutoff,
  }) {
    return {
      ...rawJson,
      if (name != null) 'name': name,
      if (upgradeAllowed != null) 'upgradeAllowed': upgradeAllowed,
      if (cutoff != null) 'cutoff': cutoff,
    };
  }
}
