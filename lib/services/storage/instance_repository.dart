import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/instance_config.dart';

/// Persists configured service instances: non-sensitive metadata (id, type,
/// label, base URL) in [SharedPreferences], API keys/secrets in
/// [FlutterSecureStorage] keyed by instance id. Splitting the two means a
/// `flutter_secure_storage` failure (e.g. no keychain on a stripped-down
/// Linux CI box) never corrupts the instance list itself.
class InstanceRepository {
  static const _prefsKey = 'stackarr.instances';
  static const _secureKeyPrefix = 'stackarr.apikey.';

  final FlutterSecureStorage _secureStorage;
  final Future<SharedPreferences> _prefsFuture;

  InstanceRepository({
    FlutterSecureStorage? secureStorage,
    Future<SharedPreferences>? prefs,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _prefsFuture = prefs ?? SharedPreferences.getInstance();

  Future<List<InstanceConfig>> loadAll() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => InstanceConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String?> getApiKey(String instanceId) {
    return _secureStorage.read(key: '$_secureKeyPrefix$instanceId');
  }

  Future<void> save(InstanceConfig config, String apiKey) async {
    await _secureStorage.write(
      key: '$_secureKeyPrefix${config.id}',
      value: apiKey,
    );
    final all = await loadAll();
    final withoutExisting = all.where((c) => c.id != config.id).toList();
    await _writeAll([...withoutExisting, config]);
  }

  Future<void> remove(String instanceId) async {
    await _secureStorage.delete(key: '$_secureKeyPrefix$instanceId');
    final all = await loadAll();
    await _writeAll(all.where((c) => c.id != instanceId).toList());
  }

  Future<void> _writeAll(List<InstanceConfig> configs) async {
    final prefs = await _prefsFuture;
    final raw = jsonEncode(configs.map((c) => c.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }
}
