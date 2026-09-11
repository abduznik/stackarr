import 'package:flutter/material.dart';
import '../../services/requests/jellyseerr_client.dart';
import '../shared/media_detail_header.dart';

/// Preview screen for one Discover search result — tapping a result now
/// shows its metadata (overview, genres, rating) before requesting,
/// rather than the tile's "+" immediately submitting a request with no
/// chance to check what it actually is first.
class DiscoverDetailScreen extends StatefulWidget {
  final JellyseerrClient client;
  final Map<String, dynamic> result;
  final VoidCallback onRequestSubmitted;

  const DiscoverDetailScreen({
    super.key,
    required this.client,
    required this.result,
    required this.onRequestSubmitted,
  });

  @override
  State<DiscoverDetailScreen> createState() => _DiscoverDetailScreenState();
}

class _DiscoverDetailScreenState extends State<DiscoverDetailScreen> {
  bool _busy = false;

  Future<void> _request() async {
    final mediaType = widget.result['mediaType'] as String?;
    if (mediaType != 'movie' && mediaType != 'tv') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This result cannot be requested')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.client.requestMedia(
        mediaId: widget.result['id'] as int,
        mediaType: mediaType == 'tv' ? 'tv' : 'movie',
      );
      widget.onRequestSubmitted();
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
    final result = widget.result;
    final title = result['title'] as String? ?? result['name'] as String? ?? '';
    final posterPath = result['posterPath'] as String?;
    final overview = result['overview'] as String?;
    final voteAverage = (result['voteAverage'] as num?)?.toDouble();
    final mediaInfo = result['mediaInfo'] as Map<String, dynamic>?;
    final alreadyRequested = mediaInfo != null;
    final releaseDate =
        result['releaseDate'] as String? ?? result['firstAirDate'] as String?;
    final year = releaseDate != null && releaseDate.length >= 4
        ? releaseDate.substring(0, 4)
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                MediaDetailHeader(
                  posterUrl: posterPath != null
                      ? 'https://image.tmdb.org/t/p/w300$posterPath'
                      : null,
                  title: title,
                  subtitle: year,
                  rating: voteAverage,
                  overview: overview,
                ),
                const Divider(height: 1),
                if (alreadyRequested)
                  const ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text('Already requested'),
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Request'),
                    onTap: _request,
                  ),
              ],
            ),
    );
  }
}
