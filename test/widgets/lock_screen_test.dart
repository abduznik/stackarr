import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackarr/screens/lock/lock_screen.dart';
import 'package:stackarr/services/storage/app_lock_repository.dart';
import '../test_helpers/secure_storage_mock.dart';

void main() {
  setUp(() {
    mockSecureStorage();
  });

  testWidgets(
      'shows PIN entry once biometric check settles (no biometrics in test)',
      (tester) async {
    await AppLockRepository().setPin('1234');

    await tester.pumpWidget(MaterialApp(
      home: LockScreen(onUnlocked: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Enter PIN'), findsOneWidget);
  });

  testWidgets('correct PIN calls onUnlocked', (tester) async {
    await AppLockRepository().setPin('1234');
    var unlocked = false;

    await tester.pumpWidget(MaterialApp(
      home: LockScreen(onUnlocked: () => unlocked = true),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await tester.pumpAndSettle();

    expect(unlocked, isTrue);
  });

  testWidgets('incorrect PIN shows an error and does not unlock',
      (tester) async {
    await AppLockRepository().setPin('1234');
    var unlocked = false;

    await tester.pumpWidget(MaterialApp(
      home: LockScreen(onUnlocked: () => unlocked = true),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await tester.pumpAndSettle();

    expect(unlocked, isFalse);
    expect(find.text('Incorrect PIN'), findsOneWidget);
  });

  testWidgets(
      'does not show the biometric shortcut when biometrics are disabled',
      (tester) async {
    await AppLockRepository().setPin('1234');

    await tester.pumpWidget(MaterialApp(
      home: LockScreen(onUnlocked: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Use biometrics'), findsNothing);
  });
}
