<p align="center">
  <img width="128" height="128" src="https://raw.githubusercontent.com/abduznik/stackarr/main/assets/icon.png" alt="Stackarr logo"/>
</p>

<h1 align="center">Stackarr</h1>

<p align="center">
  <strong>A cross-platform Flutter app to manage your entire *arr media stack</strong>
</p>

<p align="center">
  <a href="https://github.com/abduznik/stackarr/releases"><img src="https://img.shields.io/github/v/release/abduznik/stackarr?include_prereleases&style=flat-square" alt="Latest release"></a>
  <a href="https://github.com/abduznik/stackarr/blob/main/LICENSE"><img src="https://img.shields.io/github/license/abduznik/stackarr?style=flat-square" alt="License"></a>
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20Web-lightgrey?style=flat-square" alt="Platforms">
  <a href="https://github.com/abduznik/stackarr/stargazers"><img src="https://img.shields.io/github/stars/abduznik/stackarr?style=flat-square" alt="Stars"></a>
  <a href="https://github.com/abduznik/stackarr/issues"><img src="https://img.shields.io/github/issues/abduznik/stackarr?style=flat-square" alt="Issues"></a>
  <a href="https://github.com/sponsors/abduznik"><img src="https://img.shields.io/badge/Sponsor-❤️-ea4aaa?style=flat-square" alt="Sponsor"></a>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#supported-services">Services</a> •
  <a href="#installation">Install</a> •
  <a href="#setup-wizard">Setup</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a>
</p>

---

**Stackarr** is a unified Flutter client for the *arr self-hosted media stack. One app to manage movies, TV shows, music, downloads, indexers, and subtitles — instead of opening 6 different web UIs on your phone.

## Why Stackarr?

The self-hosted media ecosystem runs on *arr apps (Radarr, Sonarr, Lidarr, Prowlarr, Bazarr...). Each has its own web UI. On desktop that's fine. On mobile it's painful — tiny tables, no touch optimization, and you need 6 bookmarks.

Existing mobile clients ([Ruddarr](https://github.com/ruddarr/app), [Seekarr](https://github.com/matthw-labs/seekarr), [Dashboarr](https://apps.apple.com/app/dashboarr/id6762170117)) cover Radarr + Sonarr and maybe Lidarr. **None of them cover the full stack.** Stackarr includes:

- **Prowlarr** — indexer management and sync
- **Bazarr** — subtitle management
- **qBittorrent / Aria2** — download client control
- **Jellyseerr / Overseerr** — request management

Plus a **setup wizard** that walks you through connecting each service with auto-detection and health checks.

## Features

- 🎬 **Movies** — Radarr library: browse, search, add, monitor, quality profiles
- 📺 **TV Shows** — Sonarr library: series, seasons, episodes, air dates
- 🎵 **Music** — Lidarr library: artists, albums, track management
- 🔍 **Indexers** — Prowlarr: manage, test, and sync indexers to all *arr apps
- 📝 **Subtitles** — Bazarr: subtitle search, download, language profiles
- ⬇️ **Downloads** — qBittorrent & Aria2: queue, pause, resume, speed limits
- 📬 **Requests** — Jellyseerr / Overseerr: browse catalog, submit requests, manage pending
- 📅 **Calendar** — Unified release calendar across all services
- 🔔 **Notifications** — Push alerts for completed downloads, new episodes, failed grabs
- 🧙 **Setup Wizard** — Step-by-step connection guide with auto-detection and health checks
- 🌙 **Dark & Light Themes** — Adaptive Material 3 theming
- 📱 **Cross-Platform** — Android, iOS, Windows, Web from one Flutter codebase
- 🔒 **Local Only** — Connects to your servers directly, no cloud, no telemetry

## Supported Services

| Service | Purpose | API | Status |
|---------|---------|-----|--------|
| [Radarr](https://radarr.video/) | Movie management | v3 REST | ✅ Supported |
| [Sonarr](https://sonarr.tv/) | TV show management | v3 REST | ✅ Supported |
| [Lidarr](https://lidarr.audio/) | Music management | v3 REST | ✅ Supported |
| [Prowlarr](https://prowlarr.app/) | Indexer management | v1 REST | ✅ Supported |
| [Bazarr](https://www.bazarr.media/) | Subtitle management | REST | ✅ Supported |
| [qBittorrent](https://www.qbittorrent.org/) | Torrent downloads | Web API | ✅ Supported |
| [Aria2](https://aria2.github.io/) | Download management | JSON-RPC | ✅ Supported |
| [Jellyseerr](https://jellyseerr.dev/) | Media requests | REST | ✅ Supported |
| [Overseerr](https://overseerr.dev/) | Media requests | REST | 🔜 Planned |
| [Readarr](https://readarr.com/) | Book management | v3 REST | 🔜 Planned |
| [Whisparr](https://whisparr.com/) | Adult content | v3 REST | 🔜 Planned |

## Installation

### Android
Download the latest `.apk` from [Releases](https://github.com/abduznik/stackarr/releases) and sideload it.

### iOS
Download the `.ipa` from [Releases](https://github.com/abduznik/stackarr/releases) and install via [AltStore](https://altstore.io/) or [SideStore](https://sidestore.io/).

### Windows
Download the latest `.msi` or `.exe` installer from [Releases](https://github.com/abduznik/stackarr/releases).

### Web
Access the web build directly from your server or host it anywhere.

### Build from Source
```bash
git clone https://github.com/abduznik/stackarr.git
cd stackarr
flutter pub get
flutter run                    # auto-detects platform
flutter run -d chrome          # web
flutter build apk              # Android
flutter build windows          # Windows
```

**Requirements:** Flutter 3.x, Dart 3.x

## Setup Wizard

First launch opens the wizard:

```
Step 1: Name your instance (e.g., "Home Lab")
Step 2: Enter Radarr URL + API key → Auto-detect + health check ✓
Step 3: Enter Sonarr URL + API key → Auto-detect + health check ✓
Step 4: Enter Lidarr URL + API key → Auto-detect + health check ✓
Step 5: (Optional) Prowlarr, Bazarr, qBittorrent, Jellyseerr...
Step 6: All services connected! 🎉
```

Each step validates the connection before moving on. Add or remove services anytime in Settings.

Multiple instances supported — manage your home lab and your friend's from one app.

## Roadmap

- [ ] Unified calendar view across all services
- [ ] Push notifications (FCM / local)
- [ ] Overseerr + Readarr + Whisparr support
- [ ] Custom quality profile management
- [ ] Batch operations (mass add/remove)
- [ ] Download client switching per service
- [ ] macOS and Linux desktop builds
- [ ] Widget support (Android/iOS)
- [ ] Shortcuts / quick actions

## Contributing

Contributions welcome! Check the [issues](https://github.com/abduznik/stackarr/issues) for good first issues.

```bash
# Fork, then:
git checkout -b feature/my-feature
flutter test
flutter analyze
```

## Acknowledgments

Built on the shoulders of:
- [Servarr](https://wiki.servarr.com/) — the *arr project ecosystem and API documentation
- [Ruddarr](https://github.com/ruddarr/app) — native iOS Radarr/Sonarr client
- [Seekarr](https://github.com/matthw-labs/seekarr) — Flutter multi-service client
- [Dashboarr](https://apps.apple.com/app/dashboarr/id6762170117) — iOS arr companion

## License

[MIT](LICENSE) — use it, fork it, ship it.

---

<p align="center">
  <a href="https://github.com/sponsors/abduznik"><img src="https://img.shields.io/badge/Sponsor_Stackarr-❤️-ea4aaa?style=for-the-badge" alt="Sponsor"></a>
</p>
