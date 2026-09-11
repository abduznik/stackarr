import 'package:flutter/material.dart';
import '../../models/movie.dart';
import '../../services/arr/radarr_client.dart';
import '../shared/media_detail_header.dart';

/// Movie metadata + actions — the tap destination from the library grid,
/// matching what Radarr's own web UI shows on a movie's detail page:
/// overview, genres, rating, plus monitor toggle, manual search, and
/// delete.
class MovieDetailScreen extends StatefulWidget {
  final RadarrClient client;
  final Movie movie;
  final VoidCallback onChanged;

  const MovieDetailScreen({
    super.key,
    required this.client,
    required this.movie,
    required this.onChanged,
  });

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  late Movie _movie;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
  }

  Future<void> _toggleMonitored() async {
    setState(() => _busy = true);
    try {
      await widget.client.setMonitored(_movie.id, !_movie.monitored);
      final refreshed = await widget.client.getMovie(_movie.id);
      if (!mounted) return;
      setState(() => _movie = refreshed);
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
      await widget.client.searchMovie(_movie.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Searching for "${_movie.title}"')),
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
        title: Text('Delete "${_movie.title}"?'),
        content: const Text('This removes the movie from Radarr.'),
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
      await widget.client.deleteMovie(_movie.id);
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
      '${_movie.year}',
      if (_movie.runtime != null) '${_movie.runtime} min',
      if (_movie.certification != null) _movie.certification!,
      if (_movie.studio != null) _movie.studio!,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_movie.title)),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                MediaDetailHeader(
                  posterUrl: _movie.posterUrl,
                  title: _movie.title,
                  subtitle: subtitleParts.join(' · '),
                  genres: _movie.genres,
                  rating: _movie.tmdbRating,
                  overview: _movie.overview,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Monitored'),
                  value: _movie.monitored,
                  onChanged: (_) => _toggleMonitored(),
                ),
                ListTile(
                  leading: const Icon(Icons.search),
                  title: const Text('Search now'),
                  onTap: _searchNow,
                ),
                ListTile(
                  leading: Icon(
                    _movie.hasFile ? Icons.check_circle : Icons.schedule,
                    color: _movie.hasFile ? Colors.green : Colors.orange,
                  ),
                  title: Text(_movie.hasFile ? 'Downloaded' : 'Missing'),
                  subtitle: _movie.sizeOnDisk != null && _movie.sizeOnDisk! > 0
                      ? Text(_formatBytes(_movie.sizeOnDisk!))
                      : null,
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error),
                  title: Text('Delete',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  onTap: _delete,
                ),
              ],
            ),
    );
  }

  String _formatBytes(double bytes) {
    final gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 1) return '${gb.toStringAsFixed(2)} GB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
  }
}
