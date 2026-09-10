import 'package:flutter/material.dart';
import '../../models/instance_config.dart';
import '../../models/service_type.dart';
import '../downloads/aria2_downloads_screen.dart';
import '../downloads/downloads_screen.dart';
import '../indexers/indexers_screen.dart';
import '../movies/movies_screen.dart';
import '../music/music_screen.dart';
import '../requests/requests_screen.dart';
import '../subtitles/subtitles_screen.dart';
import '../tv/tv_screen.dart';

/// Dispatches an [InstanceConfig] to its feature screen by [ServiceType].
/// This is the single place that maps "which service" to "which UI" — add
/// a case here when a new service type gets its own screen.
class ServiceScreenRouter extends StatelessWidget {
  final InstanceConfig instance;

  const ServiceScreenRouter({super.key, required this.instance});

  @override
  Widget build(BuildContext context) {
    return switch (instance.type) {
      ServiceType.radarr => MoviesScreen(instance: instance),
      ServiceType.sonarr => TvScreen(instance: instance),
      ServiceType.lidarr => MusicScreen(instance: instance),
      ServiceType.prowlarr => IndexersScreen(instance: instance),
      ServiceType.bazarr => SubtitlesScreen(instance: instance),
      ServiceType.qbittorrent => DownloadsScreen(instance: instance),
      ServiceType.aria2 => Aria2DownloadsScreen(instance: instance),
      ServiceType.jellyseerr => RequestsScreen(instance: instance),
    };
  }
}
