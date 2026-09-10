import 'instance_config.dart';

/// One row in the unified calendar — a movie's physical/digital release
/// or a TV episode's air date, normalized from Radarr's or Sonarr's raw
/// `/calendar` JSON so the UI doesn't need to know which service it came
/// from until it wants to show a badge.
class CalendarEntry {
  final InstanceConfig sourceInstance;
  final DateTime date;
  final String title;
  final String? subtitle;
  final bool hasFile;

  const CalendarEntry({
    required this.sourceInstance,
    required this.date,
    required this.title,
    this.subtitle,
    required this.hasFile,
  });

  factory CalendarEntry.fromRadarr(
      InstanceConfig instance, Map<String, dynamic> json) {
    final dateStr = json['physicalRelease'] as String? ??
        json['digitalRelease'] as String? ??
        json['inCinemas'] as String?;
    return CalendarEntry(
      sourceInstance: instance,
      date: DateTime.tryParse(dateStr ?? '') ?? DateTime.now(),
      title: json['title'] as String? ?? 'Unknown',
      hasFile: json['hasFile'] as bool? ?? false,
    );
  }

  factory CalendarEntry.fromSonarr(
      InstanceConfig instance, Map<String, dynamic> json) {
    final series = json['series'] as Map<String, dynamic>?;
    final seasonNumber = json['seasonNumber'] as int? ?? 0;
    final episodeNumber = json['episodeNumber'] as int? ?? 0;
    return CalendarEntry(
      sourceInstance: instance,
      date: DateTime.tryParse(json['airDateUtc'] as String? ?? '') ??
          DateTime.now(),
      title:
          series?['title'] as String? ?? json['title'] as String? ?? 'Unknown',
      subtitle:
          'S${seasonNumber.toString().padLeft(2, '0')}E${episodeNumber.toString().padLeft(2, '0')}'
          ' · ${json['title'] as String? ?? ''}',
      hasFile: json['hasFile'] as bool? ?? false,
    );
  }
}
