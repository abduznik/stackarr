import '../../models/service_type.dart';
import '../download/aria2_client.dart';
import '../download/qbittorrent_client.dart';
import '../requests/jellyseerr_client.dart';
import 'bazarr_client.dart';
import 'lidarr_client.dart';
import 'prowlarr_client.dart';
import 'radarr_client.dart';
import 'sonarr_client.dart';

/// Builds the right typed client for a [ServiceType] and runs its health
/// check — used by the setup wizard so it doesn't need a switch statement
/// per screen. qBittorrent and Aria2 take different credential shapes than
/// the API-key services, hence the optional username/password/rpcSecret
/// params instead of a single apiKey everywhere.
class ServiceClientFactory {
  static Future<bool> checkHealth({
    required ServiceType type,
    required String baseUrl,
    String? apiKey,
    String? username,
    String? password,
  }) async {
    switch (type) {
      case ServiceType.radarr:
        final client = RadarrClient(baseUrl: baseUrl, apiKey: apiKey ?? '');
        final ok = await client.checkHealth();
        client.close();
        return ok;
      case ServiceType.sonarr:
        final client = SonarrClient(baseUrl: baseUrl, apiKey: apiKey ?? '');
        final ok = await client.checkHealth();
        client.close();
        return ok;
      case ServiceType.lidarr:
        final client = LidarrClient(baseUrl: baseUrl, apiKey: apiKey ?? '');
        final ok = await client.checkHealth();
        client.close();
        return ok;
      case ServiceType.prowlarr:
        final client = ProwlarrClient(baseUrl: baseUrl, apiKey: apiKey ?? '');
        final ok = await client.checkHealth();
        client.close();
        return ok;
      case ServiceType.bazarr:
        final client = BazarrClient(baseUrl: baseUrl, apiKey: apiKey ?? '');
        final ok = await client.checkHealth();
        client.close();
        return ok;
      case ServiceType.qbittorrent:
        final client = QbittorrentClient(
          baseUrl: baseUrl,
          username: username ?? '',
          password: password ?? '',
        );
        final ok = await client.checkHealth();
        client.close();
        return ok;
      case ServiceType.aria2:
        final client = Aria2Client(baseUrl: baseUrl, rpcSecret: apiKey);
        final ok = await client.checkHealth();
        client.close();
        return ok;
      case ServiceType.jellyseerr:
        final client = JellyseerrClient(baseUrl: baseUrl, apiKey: apiKey ?? '');
        final ok = await client.checkHealth();
        client.close();
        return ok;
    }
  }
}
