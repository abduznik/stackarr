import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/instance_providers.dart';
import 'screens/dashboard/app_shell.dart';
import 'screens/lock/lock_screen.dart';
import 'screens/setup/setup_wizard_screen.dart';
import 'services/storage/app_lock_repository.dart';

void main() {
  runApp(const ProviderScope(child: StackarrApp()));
}

class StackarrApp extends StatelessWidget {
  const StackarrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stackarr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const _RootRouter(),
    );
  }
}

/// Gates the app behind [LockScreen] when an app lock is configured,
/// then routes to the setup wizard on first run (no instances configured
/// yet) or straight to the app shell once at least one service is
/// connected.
class _RootRouter extends ConsumerStatefulWidget {
  const _RootRouter();

  @override
  ConsumerState<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends ConsumerState<_RootRouter> {
  final _lockRepo = AppLockRepository();
  bool? _isLocked;

  @override
  void initState() {
    super.initState();
    _checkLock();
  }

  Future<void> _checkLock() async {
    final enabled = await _lockRepo.isLockEnabled();
    if (mounted) setState(() => _isLocked = enabled);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isLocked == true) {
      return LockScreen(onUnlocked: () => setState(() => _isLocked = false));
    }

    final hasInstanceAsync = ref.watch(hasAnyInstanceProvider);

    return hasInstanceAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (hasInstance) => hasInstance
          ? const AppShell()
          : SetupWizardScreen(
              onFinished: () => ref.invalidate(hasAnyInstanceProvider),
            ),
    );
  }
}
