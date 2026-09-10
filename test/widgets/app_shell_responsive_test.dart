import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stackarr/screens/dashboard/app_shell.dart';

/// Common device sizes covering the two layouts AppShell switches between:
/// a NavigationRail above the Material 3 600dp breakpoint (desktop windows,
/// tablets in landscape) and a bottom NavigationBar below it (phones,
/// tablets in portrait). See lib/screens/dashboard/app_shell.dart.
const _desktopLandscape = Size(1440, 900);
const _tabletLandscape = Size(1024, 768);
const _phonePortrait = Size(390, 844); // iPhone 14-class
const _phoneLandscape = Size(844, 390);
const _smallPhonePortrait = Size(360, 640); // common Android baseline

Future<void> _pumpShellAt(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({
    'stackarr.instances': '''
    [
      {"id":"1","type":"radarr","label":"Movies","baseUrl":"http://localhost:7878"},
      {"id":"2","type":"sonarr","label":"TV","baseUrl":"http://localhost:8989"}
    ]
    ''',
  });

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(home: AppShell()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows NavigationRail on desktop landscape (1440x900)',
      (tester) async {
    await _pumpShellAt(tester, _desktopLandscape);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('shows NavigationRail on tablet landscape (1024x768)',
      (tester) async {
    await _pumpShellAt(tester, _tabletLandscape);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('shows bottom NavigationBar on phone portrait (390x844)',
      (tester) async {
    await _pumpShellAt(tester, _phonePortrait);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('shows bottom NavigationBar on small phone portrait (360x640)',
      (tester) async {
    await _pumpShellAt(tester, _smallPhonePortrait);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets(
      'switches to NavigationRail when phone rotates to landscape (844x390)',
      (tester) async {
    await _pumpShellAt(tester, _phoneLandscape);

    // 844dp width crosses the 600dp breakpoint, so a rotated phone gets
    // the rail layout too — matches Material 3 adaptive guidance.
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets(
      'lists every configured instance plus Home, Calendar and Settings',
      (tester) async {
    await _pumpShellAt(tester, _desktopLandscape);

    final rail = find.byType(NavigationRail);
    expect(rail, findsOneWidget);
    expect(
        find.descendant(of: rail, matching: find.text('Home')), findsOneWidget);
    expect(find.descendant(of: rail, matching: find.text('Calendar')),
        findsOneWidget);
    expect(find.descendant(of: rail, matching: find.text('Movies')),
        findsOneWidget);
    expect(
        find.descendant(of: rail, matching: find.text('TV')), findsOneWidget);
    expect(find.descendant(of: rail, matching: find.text('Settings')),
        findsOneWidget);
  });

  testWidgets('hides Calendar when no Radarr/Sonarr instance is configured',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'stackarr.instances': '''
      [
        {"id":"1","type":"qbittorrent","label":"Downloads","baseUrl":"http://localhost:8080"}
      ]
      ''',
    });
    tester.view.physicalSize = _desktopLandscape;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AppShell())),
    );
    await tester.pumpAndSettle();

    final rail = find.byType(NavigationRail);
    expect(find.descendant(of: rail, matching: find.text('Calendar')),
        findsNothing);
  });

  testWidgets('navigating between destinations updates the body',
      (tester) async {
    await _pumpShellAt(tester, _phonePortrait);

    // Home is selected first.
    expect(find.text('No services configured yet'), findsNothing);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    expect(find.text('Configured services'), findsOneWidget);
  });
}
