import 'package:flutter/material.dart';
import '../../services/requests/jellyseerr_client.dart';
import '../shared/media_detail_header.dart';

/// Detail view for one Jellyseerr request — fetches the real TMDB
/// metadata (title, overview, genres, rating) since the request list
/// itself only carries ids, plus approve/decline for pending requests.
class RequestDetailScreen extends StatefulWidget {
  final JellyseerrClient client;
  final Map<String, dynamic> request;
  final VoidCallback onChanged;

  const RequestDetailScreen({
    super.key,
    required this.client,
    required this.request,
    required this.onChanged,
  });

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  late Future<Map<String, dynamic>> _detailsFuture;
  bool _busy = false;

  int get _requestId => widget.request['id'] as int;
  int get _status => widget.request['status'] as int? ?? 0;
  bool get _isPending => _status == 1;

  @override
  void initState() {
    super.initState();
    final media = widget.request['media'] as Map<String, dynamic>?;
    final tmdbId = media?['tmdbId'] as int?;
    final mediaType = media?['mediaType'] as String? ?? 'movie';
    _detailsFuture = tmdbId != null
        ? widget.client.getMediaDetails(tmdbId: tmdbId, mediaType: mediaType)
        : Future.value(<String, dynamic>{});
  }

  Future<void> _respond(String action) async {
    setState(() => _busy = true);
    try {
      await widget.client.updateRequestStatus(_requestId, action);
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  String _statusLabel(int status) => switch (status) {
        1 => 'Pending approval',
        2 => 'Approved',
        3 => 'Declined',
        4 => 'Available',
        _ => 'Unknown',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<Map<String, dynamic>>(
              future: _detailsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final details = snapshot.data ?? {};
                final title = details['title'] as String? ??
                    details['name'] as String? ??
                    'Request #$_requestId';
                final overview = details['overview'] as String?;
                final posterPath = details['posterPath'] as String?;
                final genres = (details['genres'] as List<dynamic>?)
                        ?.map((g) => (g as Map)['name'] as String)
                        .toList() ??
                    const <String>[];
                final voteAverage =
                    (details['voteAverage'] as num?)?.toDouble();

                return ListView(
                  children: [
                    MediaDetailHeader(
                      posterUrl: posterPath != null
                          ? 'https://image.tmdb.org/t/p/w300$posterPath'
                          : null,
                      title: title,
                      subtitle: _statusLabel(_status),
                      genres: genres,
                      rating: voteAverage,
                      overview: overview,
                    ),
                    if (_isPending) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.check, color: Colors.green),
                        title: const Text('Approve'),
                        onTap: () => _respond('approve'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.close, color: Colors.red),
                        title: const Text('Decline'),
                        onTap: () => _respond('decline'),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}
