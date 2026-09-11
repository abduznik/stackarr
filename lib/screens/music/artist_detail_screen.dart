import 'package:flutter/material.dart';
import '../../models/album.dart';
import '../../models/artist.dart';
import '../../services/arr/lidarr_client.dart';
import '../shared/media_detail_header.dart';

/// Artist metadata + album list — the tap destination from the music
/// library grid, matching Lidarr's own web UI: overview, genres, rating,
/// plus monitor toggle, manual search, delete, and the artist's albums.
class ArtistDetailScreen extends StatefulWidget {
  final LidarrClient client;
  final Artist artist;
  final VoidCallback onChanged;

  const ArtistDetailScreen({
    super.key,
    required this.client,
    required this.artist,
    required this.onChanged,
  });

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  late Artist _artist;
  late Future<List<Album>> _albumsFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _artist = widget.artist;
    _albumsFuture = widget.client.getAlbums(_artist.id);
  }

  Future<void> _toggleMonitored() async {
    setState(() => _busy = true);
    try {
      await widget.client.setArtistMonitored(_artist.id, !_artist.monitored);
      final refreshed = (await widget.client.getArtists())
          .firstWhere((a) => a.id == _artist.id, orElse: () => _artist);
      if (!mounted) return;
      setState(() => _artist = refreshed);
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _searchNow() async {
    setState(() => _busy = true);
    try {
      await widget.client.searchArtist(_artist.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Searching for "${_artist.artistName}"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${_artist.artistName}"?'),
        content: const Text('This removes the artist from Lidarr.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await widget.client.deleteArtist(_artist.id);
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (_artist.disambiguation != null && _artist.disambiguation!.isNotEmpty)
        _artist.disambiguation!,
      _artist.status,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_artist.artistName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _delete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                MediaDetailHeader(
                  posterUrl: _artist.posterUrl,
                  title: _artist.artistName,
                  subtitle: subtitleParts.join(' · '),
                  genres: _artist.genres,
                  rating: _artist.rating,
                  overview: _artist.overview,
                ),
                SwitchListTile(
                  title: const Text('Monitored'),
                  value: _artist.monitored,
                  onChanged: (_) => _toggleMonitored(),
                ),
                ListTile(
                  leading: const Icon(Icons.search),
                  title: const Text('Search now'),
                  onTap: _searchNow,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Albums',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                FutureBuilder<List<Album>>(
                  future: _albumsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }
                    final albums = snapshot.data ?? [];
                    if (albums.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No albums found'),
                      );
                    }
                    return Column(
                      children: [
                        for (final album in albums)
                          ListTile(
                            leading: Icon(
                              album.hasFile
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: album.hasFile ? Colors.green : null,
                            ),
                            title: Text(album.title),
                            subtitle: Text([
                              if (album.releaseDate != null)
                                album.releaseDate!.split('T').first,
                              '${album.trackCount} tracks',
                            ].join(' · ')),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
}
