import 'service_type.dart';

/// A configured connection to one *arr/download/request service.
///
/// [apiKey] is intentionally excluded from [toJson]/[fromJson] — credentials
/// live in secure storage keyed by [id], while this metadata (host, label,
/// service type) lives in shared_preferences. See InstanceRepository.
class InstanceConfig {
  final String id;
  final ServiceType type;
  final String label;
  final String baseUrl;
  final bool useApiKeyHeader;

  const InstanceConfig({
    required this.id,
    required this.type,
    required this.label,
    required this.baseUrl,
  }) : useApiKeyHeader = true;

  InstanceConfig copyWith({
    String? label,
    String? baseUrl,
  }) {
    return InstanceConfig(
      id: id,
      type: type,
      label: label ?? this.label,
      baseUrl: baseUrl ?? this.baseUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'label': label,
        'baseUrl': baseUrl,
      };

  factory InstanceConfig.fromJson(Map<String, dynamic> json) {
    return InstanceConfig(
      id: json['id'] as String,
      type: ServiceType.values.byName(json['type'] as String),
      label: json['label'] as String,
      baseUrl: json['baseUrl'] as String,
    );
  }
}
