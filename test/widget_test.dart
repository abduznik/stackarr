import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stackarr/main.dart';

void main() {
  testWidgets('StackarrApp shows the setup wizard with no instances configured',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: StackarrApp()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Stackarr'), findsOneWidget);
    expect(find.text('Radarr'), findsOneWidget);
    expect(find.text('Sonarr'), findsOneWidget);
  });
}
