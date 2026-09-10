import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/calendar_entry.dart';
import '../../models/instance_config.dart';
import '../../models/service_type.dart';
import '../../providers/instance_providers.dart';
import '../../services/arr/radarr_client.dart';
import '../../services/arr/sonarr_client.dart';
import '../../services/storage/instance_repository.dart';

/// Merges calendar entries across every configured Radarr and Sonarr
/// instance for a month window, keyed by day — this is what makes it a
/// "unified" calendar rather than one per service.
final calendarEntriesProvider =
    FutureProvider.family<Map<DateTime, List<CalendarEntry>>, DateTime>(
        (ref, month) async {
  final instances = await ref.watch(instancesProvider.future);
  final repo = InstanceRepository();
  final start = DateTime(month.year, month.month - 1, 1);
  final end = DateTime(month.year, month.month + 2, 0);

  final entries = <CalendarEntry>[];

  for (final instance in instances) {
    if (instance.type != ServiceType.radarr &&
        instance.type != ServiceType.sonarr) {
      continue;
    }
    final apiKey = await repo.getApiKey(instance.id);
    try {
      if (instance.type == ServiceType.radarr) {
        final client =
            RadarrClient(baseUrl: instance.baseUrl, apiKey: apiKey ?? '');
        final raw = await client.getCalendar(start: start, end: end);
        client.close();
        entries.addAll(raw.map((e) =>
            CalendarEntry.fromRadarr(instance, e as Map<String, dynamic>)));
      } else {
        final client =
            SonarrClient(baseUrl: instance.baseUrl, apiKey: apiKey ?? '');
        final raw = await client.getCalendar(start: start, end: end);
        client.close();
        entries.addAll(raw.map((e) =>
            CalendarEntry.fromSonarr(instance, e as Map<String, dynamic>)));
      }
    } catch (_) {
      // One unreachable instance shouldn't blank the whole calendar —
      // its entries are simply missing for this refresh.
      continue;
    }
  }

  final byDay = <DateTime, List<CalendarEntry>>{};
  for (final entry in entries) {
    final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
    byDay.putIfAbsent(day, () => []).add(entry);
  }
  return byDay;
});

/// Unified release calendar across every configured Radarr/Sonarr
/// instance — movies' release dates and episodes' air dates on one
/// month view, replacing the need to check each service separately.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(calendarEntriesProvider(_focusedMonth));

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (byDay) {
          final selected = _selectedDay ?? DateTime.now();
          final normalizedSelected =
              DateTime(selected.year, selected.month, selected.day);
          final dayEntries = byDay[normalizedSelected] ?? [];

          return Column(
            children: [
              TableCalendar<CalendarEntry>(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedMonth,
                selectedDayPredicate: (day) =>
                    isSameDay(day, _selectedDay ?? DateTime.now()),
                eventLoader: (day) {
                  final key = DateTime(day.year, day.month, day.day);
                  return byDay[key] ?? [];
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedMonth = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  setState(() => _focusedMonth = focusedDay);
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: dayEntries.isEmpty
                    ? const Center(child: Text('Nothing scheduled'))
                    : ListView.builder(
                        itemCount: dayEntries.length,
                        itemBuilder: (context, index) =>
                            _EntryTile(entry: dayEntries[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final CalendarEntry entry;

  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isMovie = entry.sourceInstance.type == ServiceType.radarr;
    return ListTile(
      leading: Icon(isMovie ? Icons.movie_outlined : Icons.tv_outlined),
      title: Text(entry.title),
      subtitle: Text(entry.subtitle ?? entry.sourceInstance.label),
      trailing: Icon(
        entry.hasFile ? Icons.check_circle : Icons.schedule,
        color: entry.hasFile ? Colors.green : Colors.orange,
      ),
    );
  }
}

/// Used by AppShell to decide whether Calendar belongs in the nav — only
/// worth showing once at least one Radarr or Sonarr instance is connected.
bool hasCalendarCapableInstance(List<InstanceConfig> instances) {
  return instances
      .any((i) => i.type == ServiceType.radarr || i.type == ServiceType.sonarr);
}
