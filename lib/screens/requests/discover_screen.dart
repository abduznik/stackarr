import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/requests/jellyseerr_client.dart';

/// Search + submit-a-request screen — Jellyseerr's own web UI calls this
/// "Discover"/search. Without this, RequestsScreen could only
/// approve/decline requests other people already made; there was no way
/// to actually request something new from within the app.
class DiscoverScreen extends StatefulWidget {
  final JellyseerrClient client;
  final VoidCallback onRequestSubmitted;

  const DiscoverScreen(
      {super.key, required this.client, required this.onRequestSubmitted});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _searchController = TextEditingController();
  List<dynamic>? _results;
  bool _searching = false;
  String? _error;

  Future<void> _search(String term) async {
    if (term.trim().isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await widget.client.searchMedia(term.trim());
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _searching = false;
      });
    }
  }

  Future<void> _requestMedia(Map<String, dynamic> result) async {
    final mediaType = result['mediaType'] as String?;
    if (mediaType != 'movie' && mediaType != 'tv') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This result cannot be requested')),
      );
      return;
    }

    try {
      await widget.client.requestMedia(
        mediaId: result['id'] as int,
        mediaType: mediaType == 'tv' ? 'tv' : 'movie',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Requested "${result['title'] ?? result['name'] ?? 'media'}"')),
      );
      widget.onRequestSubmitted();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to request: $e')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search movies and TV shows...',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : null,
            ),
            onSubmitted: _search,
            textInputAction: TextInputAction.search,
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: _results == null
              ? const Center(child: Text('Search to find something to request'))
              : _results!.isEmpty
                  ? const Center(child: Text('No results'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 160,
                        childAspectRatio: 0.6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _results!.length,
                      itemBuilder: (context, index) {
                        final result = _results![index] as Map<String, dynamic>;
                        return _DiscoverTile(
                          result: result,
                          onRequest: () => _requestMedia(result),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _DiscoverTile extends StatelessWidget {
  final Map<String, dynamic> result;
  final VoidCallback onRequest;

  const _DiscoverTile({required this.result, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    final title = result['title'] as String? ?? result['name'] as String? ?? '';
    final posterPath = result['posterPath'] as String?;
    final mediaInfo = result['mediaInfo'] as Map<String, dynamic>?;
    final alreadyRequested = mediaInfo != null;

    return GestureDetector(
      onTap: alreadyRequested ? null : onRequest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: posterPath != null
                      ? CachedNetworkImage(
                          imageUrl:
                              'https://image.tmdb.org/t/p/w300$posterPath',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const ColoredBox(color: Colors.black12),
                        )
                      : const ColoredBox(color: Colors.black12),
                ),
                if (alreadyRequested)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Chip(
                      label: const Text('Requested',
                          style: TextStyle(fontSize: 10)),
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                else
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: FloatingActionButton.small(
                      onPressed: onRequest,
                      child: const Icon(Icons.add),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
