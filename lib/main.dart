import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/instance_providers.dart';
import 'screens/dashboard/app_shell.dart';
import 'screens/setup/setup_wizard_screen.dart';

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

/// Routes to the setup wizard on first run (no instances configured yet)
/// or straight to the app shell once at least one service is connected.
class _RootRouter extends ConsumerWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
