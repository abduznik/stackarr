import 'package:flutter/material.dart';

/// Activity/queue list shared by Radarr, Sonarr, and Lidarr — their
/// `/queue` endpoints all return the same record shape (title, size,
/// sizeleft, status, trackedDownloadStatus, timeleft), so one widget
/// driven by a raw record fetcher covers all three instead of three
/// near-identical queue screens.
class QueueTab extends StatelessWidget {
  final Future<List<dynamic>> Function() onLoadQueue;

  const QueueTab({super.key, required this.onLoadQueue});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: onLoadQueue(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return const Center(child: Text('Queue is empty'));
        }
        return ListView.builder(
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index] as Map<String, dynamic>;
            final size = (record['size'] as num?)?.toDouble() ?? 0;
            final sizeLeft = (record['sizeleft'] as num?)?.toDouble() ?? 0;
            final progress =
                size > 0 ? (1 - (sizeLeft / size)).clamp(0.0, 1.0) : 0.0;
            final status = record['status'] as String? ?? 'unknown';
            final timeLeft = record['timeleft'] as String?;

            return ListTile(
              title: Text(record['title'] as String? ?? 'Unknown',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 4),
                  Text([
                    '${(progress * 100).toStringAsFixed(0)}%',
                    status,
                    if (timeLeft != null) timeLeft,
                  ].join(' · ')),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
