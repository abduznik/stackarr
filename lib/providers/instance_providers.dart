import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/instance_config.dart';
import '../services/storage/instance_repository.dart';

final instanceRepositoryProvider = Provider<InstanceRepository>((ref) {
  return InstanceRepository();
});

/// The list of configured instances. Loaded once on first read; call
/// `ref.invalidate(instancesProvider)` after add/remove to refresh.
final instancesProvider = FutureProvider<List<InstanceConfig>>((ref) async {
  final repo = ref.watch(instanceRepositoryProvider);
  return repo.loadAll();
});

/// True once at least one instance has been configured — the router uses
/// this to decide between the setup wizard and the main app shell.
final hasAnyInstanceProvider = FutureProvider<bool>((ref) async {
  final instances = await ref.watch(instancesProvider.future);
  return instances.isNotEmpty;
});
