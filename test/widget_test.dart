import 'package:flutter_test/flutter_test.dart';

import 'package:stackarr/main.dart';

void main() {
  testWidgets('StackarrApp shows placeholder screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const StackarrApp());

    expect(find.text('Stackarr — Coming Soon'), findsOneWidget);
  });
}
