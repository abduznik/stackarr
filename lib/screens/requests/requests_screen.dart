import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/instance_config.dart';
import '../../services/requests/jellyseerr_client.dart';
import '../../services/storage/instance_repository.dart';

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
/// approve/decline actions, mirroring Jellyseerr's own request list.
class RequestsScreen extends ConsumerWidget {
  final InstanceConfig instance;

  const RequestsScreen({super.key, required this.instance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_requestsProvider(instance));

    return Scaffold(
      appBar: AppBar(title: Text(instance.label)),
      body: requestsAsync.when(
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
                final media = r['media'] as Map<String, dynamic>?;
                final status = r['status'] as int? ?? 0;
                final isPending = status == 1;
                final requestId = r['id'] as int;

                return ListTile(
                  leading: Icon(media?['mediaType'] == 'tv'
                      ? Icons.tv
                      : Icons.movie_outlined),
                  title: Text('Request #$requestId'),
                  subtitle: Text(_statusLabel(status)),
                  trailing: isPending
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.check, color: Colors.green),
                              onPressed: () async {
                                final client = await ref.read(
                                    _jellyseerrClientProvider(instance).future);
                                await client.updateRequestStatus(
                                    requestId, 'approve');
                                ref.invalidate(_requestsProvider(instance));
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () async {
                                final client = await ref.read(
                                    _jellyseerrClientProvider(instance).future);
                                await client.updateRequestStatus(
                                    requestId, 'decline');
                                ref.invalidate(_requestsProvider(instance));
                              },
                            ),
                          ],
                        )
                      : null,
                );
              },
            ),
          );
        },
      ),
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
