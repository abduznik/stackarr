import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackarr/screens/lock/set_pin_screen.dart';
import 'package:stackarr/services/storage/app_lock_repository.dart';
import '../test_helpers/secure_storage_mock.dart';

void main() {
  setUp(() {
    mockSecureStorage();
  });

  testWidgets('entering a valid PIN then confirming it saves the PIN',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SetPinScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Choose a PIN'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm PIN'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    final repo = AppLockRepository();
    expect(await repo.isLockEnabled(), isTrue);
    expect(await repo.verifyPin('1234'), isTrue);
  });

  testWidgets('a PIN shorter than 4 digits shows an error and does not advance',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SetPinScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    expect(find.text('PIN must be at least 4 digits'), findsOneWidget);
    expect(find.text('Choose a PIN'), findsOneWidget);
  });

  testWidgets('mismatched confirmation resets back to the first step',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SetPinScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '5678');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('PINs did not match'), findsOneWidget);
    expect(find.text('Choose a PIN'), findsOneWidget);

    final repo = AppLockRepository();
    expect(await repo.isLockEnabled(), isFalse);
  });
}
