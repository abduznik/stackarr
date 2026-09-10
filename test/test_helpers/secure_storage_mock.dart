import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// flutter_secure_storage has no test-mode fallback — its platform
/// channel call just hangs forever in widget tests (never resolves,
/// never throws), which silently times out pumpAndSettle rather than
/// failing fast with a clear error. Any widget test that exercises a
/// screen touching InstanceRepository or AppLockRepository needs this
/// mock installed first, e.g. in a `setUp`.
void mockSecureStorage() {
  final storage = <String, String>{};
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
    switch (call.method) {
      case 'read':
        final key = call.arguments['key'] as String;
        return storage[key];
      case 'write':
        final key = call.arguments['key'] as String;
        final value = call.arguments['value'] as String?;
        if (value == null) {
          storage.remove(key);
        } else {
          storage[key] = value;
        }
        return null;
      case 'delete':
        storage.remove(call.arguments['key'] as String);
        return null;
      case 'deleteAll':
        storage.clear();
        return null;
      case 'readAll':
        return storage;
      case 'containsKey':
        return storage.containsKey(call.arguments['key'] as String);
      default:
        return null;
    }
  });
}
