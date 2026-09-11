import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/instance_config.dart';
import '../../services/requests/jellyseerr_client.dart';
import '../../services/storage/instance_repository.dart';
import '../shared/library_search_bar.dart';
import 'discover_screen.dart';
import 'request_detail_screen.dart';

final _jellyseerrClientProvider =
    FutureProvider.family<JellyseerrClient, InstanceConfig>(
        (ref, instance) async {
  final repo = InstanceRepository();
  final apiKey = await repo.getApiKey(instance.id);
  return JellyseerrClient(baseUrl: instance.baseUrl, apiKey: apiKey ?? '');
});

final _requestsProvider =
    FutureProvider.family<List<dynamic>, InstanceConfig>((ref, instance) async {
  final client = await ref.watch(_jellyseerrClientProvider(instance).future);
  return client.getRequests();
});

/// Jellyseerr requests inbox: pending/approved/declined requests with
/// approve/decline actions, mirroring Jellyseerr's own request list, plus
/// a Discover tab to search and submit new requests — the "Requests"
/// list alone couldn't create anything, only react to what other people
/// already asked for.
///
/// Each request row's real title is fetched lazily (Jellyseerr's /request
/// list only embeds tmdbId/mediaType, not the title) so search-by-title
/// and tap-to-detail both work — previously rows just showed
/// "Request #id" with no way to tell what was actually requested.
class RequestsScreen extends ConsumerStatefulWidget {
  final InstanceConfig instance;

  const RequestsScreen({super.key, required this.instance});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen> {
  String _query = '';

  InstanceConfig get instance => widget.instance;

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(_requestsProvider(instance));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(instance.label),
          actions: [
            LibrarySearchBar(
              hintText: 'Search requests...',
              onQueryChanged: (q) => setState(() => _query = q),
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Requests'),
            Tab(text: 'Discover'),
          ]),
        ),
        body: TabBarView(
          children: [
            _buildRequestsList(context, ref, requestsAsync),
            _buildDiscoverTab(ref),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverTab(WidgetRef ref) {
    return FutureBuilder<JellyseerrClient>(
      future: ref.read(_jellyseerrClientProvider(instance).future),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return DiscoverScreen(
          client: snapshot.data!,
          onRequestSubmitted: () => ref.invalidate(_requestsProvider(instance)),
        );
      },
    );
  }

  Widget _buildRequestsList(BuildContext context, WidgetRef ref,
      AsyncValue<List<dynamic>> requestsAsync) {
    return requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(child: Text('No requests'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_requestsProvider(instance)),
            child: ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final r = requests[index] as Map<String, dynamic>;
                return _RequestTile(
                  request: r,
                  instance: instance,
                  query: _query,
                );
              },
            ),
          );
        });
  }
}

class _RequestTile extends ConsumerWidget {
  final Map<String, dynamic> request;
  final InstanceConfig instance;
  final String query;

  const _RequestTile({
    required this.request,
    required this.instance,
    required this.query,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = request['media'] as Map<String, dynamic>?;
    final status = request['status'] as int? ?? 0;
    final isPending = status == 1;
    final requestId = request['id'] as int;
    final tmdbId = media?['tmdbId'] as int?;
    final mediaType = media?['mediaType'] as String? ?? 'movie';

    return FutureBuilder<Map<String, dynamic>>(
      future: tmdbId != null
          ? ref
              .read(_jellyseerrClientProvider(instance).future)
              .then((c) => c.getMediaDetails(
                    tmdbId: tmdbId,
                    mediaType: mediaType,
                  ))
          : Future.value(<String, dynamic>{}),
      builder: (context, snapshot) {
        final details = snapshot.data;
        final title = details?['title'] as String? ??
            details?['name'] as String? ??
            'Request #$requestId';

        if (query.trim().isNotEmpty &&
            !title.toLowerCase().contains(query.trim().toLowerCase())) {
          return const SizedBox.shrink();
        }

        return ListTile(
          leading: Icon(mediaType == 'tv' ? Icons.tv : Icons.movie_outlined),
          title: Text(title),
          subtitle: Text(_statusLabel(status)),
          onTap: () async {
            final client =
                await ref.read(_jellyseerrClientProvider(instance).future);
            if (!context.mounted) return;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RequestDetailScreen(
                  client: client,
                  request: request,
                  onChanged: () => ref.invalidate(_requestsProvider(instance)),
                ),
              ),
            );
          },
          trailing: isPending
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () async {
                        final client = await ref
                            .read(_jellyseerrClientProvider(instance).future);
                        await client.updateRequestStatus(requestId, 'approve');
                        ref.invalidate(_requestsProvider(instance));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () async {
                        final client = await ref
                            .read(_jellyseerrClientProvider(instance).future);
                        await client.updateRequestStatus(requestId, 'decline');
                        ref.invalidate(_requestsProvider(instance));
                      },
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }

  String _statusLabel(int status) => switch (status) {
        1 => 'Pending approval',
        2 => 'Approved',
        3 => 'Declined',
        4 => 'Available',
        _ => 'Unknown',
      };
}
