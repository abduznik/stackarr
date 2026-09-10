import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackarr/screens/shared/selectable_grid.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  const delegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 160,
    childAspectRatio: 0.6,
  );

  testWidgets('tap with nothing selected calls onTapItem, not selection',
      (tester) async {
    int? tapped;
    await tester.pumpWidget(_wrap(SelectableGrid<int>(
      items: const [1, 2, 3],
      idOf: (i) => i,
      gridDelegate: delegate,
      actions: const [],
      onActionCompleted: () {},
      onRefresh: () async {},
      onTapItem: (item) => tapped = item,
      itemBuilder: (context, item, selected, onToggle) =>
          Text('item-$item${selected ? '-selected' : ''}'),
    )));

    await tester.tap(find.text('item-2'));
    await tester.pump();

    expect(tapped, 2);
    expect(find.text('item-2-selected'), findsNothing);
  });

  testWidgets('long-press enters selection mode and shows the action bar',
      (tester) async {
    await tester.pumpWidget(_wrap(SelectableGrid<int>(
      items: const [1, 2, 3],
      idOf: (i) => i,
      gridDelegate: delegate,
      actions: [
        BulkAction(
            icon: Icons.bookmark, label: 'Monitor', onRun: (ids) async {}),
      ],
      onActionCompleted: () {},
      onRefresh: () async {},
      itemBuilder: (context, item, selected, onToggle) =>
          Text('item-$item${selected ? '-selected' : ''}'),
    )));

    await tester.longPress(find.text('item-2'));
    await tester.pump();

    expect(find.text('item-2-selected'), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets('tap while selecting toggles instead of calling onTapItem',
      (tester) async {
    int? tapped;
    await tester.pumpWidget(_wrap(SelectableGrid<int>(
      items: const [1, 2, 3],
      idOf: (i) => i,
      gridDelegate: delegate,
      actions: const [],
      onActionCompleted: () {},
      onRefresh: () async {},
      onTapItem: (item) => tapped = item,
      itemBuilder: (context, item, selected, onToggle) =>
          Text('item-$item${selected ? '-selected' : ''}'),
    )));

    await tester.longPress(find.text('item-1'));
    await tester.pump();
    await tester.tap(find.text('item-2'));
    await tester.pump();

    expect(tapped, isNull);
    expect(find.text('item-1-selected'), findsOneWidget);
    expect(find.text('item-2-selected'), findsOneWidget);
    expect(find.text('2 selected'), findsOneWidget);
  });

  testWidgets('non-destructive action runs immediately without a dialog',
      (tester) async {
    List<int>? receivedIds;
    await tester.pumpWidget(_wrap(SelectableGrid<int>(
      items: const [1, 2, 3],
      idOf: (i) => i,
      gridDelegate: delegate,
      actions: [
        BulkAction(
          icon: Icons.bookmark,
          label: 'Monitor',
          onRun: (ids) async => receivedIds = ids,
        ),
      ],
      onActionCompleted: () {},
      onRefresh: () async {},
      itemBuilder: (context, item, selected, onToggle) =>
          Text('item-$item${selected ? '-selected' : ''}'),
    )));

    await tester.longPress(find.text('item-1'));
    await tester.pump();
    await tester.tap(find.text('item-3'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.bookmark));
    await tester.pumpAndSettle();

    expect(receivedIds, unorderedEquals([1, 3]));
    // Selection clears after a successful action.
    expect(find.text('selected'), findsNothing);
  });

  testWidgets('destructive action shows a confirm dialog before running',
      (tester) async {
    var ran = false;
    await tester.pumpWidget(_wrap(SelectableGrid<int>(
      items: const [1, 2, 3],
      idOf: (i) => i,
      gridDelegate: delegate,
      actions: [
        BulkAction(
          icon: Icons.delete_outline,
          label: 'Delete',
          destructive: true,
          onRun: (ids) async => ran = true,
        ),
      ],
      onActionCompleted: () {},
      onRefresh: () async {},
      itemBuilder: (context, item, selected, onToggle) =>
          Text('item-$item${selected ? '-selected' : ''}'),
    )));

    await tester.longPress(find.text('item-1'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // Dialog is showing; action hasn't run yet.
    expect(ran, isFalse);
    expect(find.text('Apply "Delete" to 1 item(s)?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(ran, isTrue);
  });

  testWidgets('cancelling the confirm dialog does not run the action',
      (tester) async {
    var ran = false;
    await tester.pumpWidget(_wrap(SelectableGrid<int>(
      items: const [1, 2, 3],
      idOf: (i) => i,
      gridDelegate: delegate,
      actions: [
        BulkAction(
          icon: Icons.delete_outline,
          label: 'Delete',
          destructive: true,
          onRun: (ids) async => ran = true,
        ),
      ],
      onActionCompleted: () {},
      onRefresh: () async {},
      itemBuilder: (context, item, selected, onToggle) =>
          Text('item-$item${selected ? '-selected' : ''}'),
    )));

    await tester.longPress(find.text('item-1'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(ran, isFalse);
    // Selection is preserved after cancelling.
    expect(find.text('item-1-selected'), findsOneWidget);
  });

  testWidgets('tapping the close icon clears selection', (tester) async {
    await tester.pumpWidget(_wrap(SelectableGrid<int>(
      items: const [1, 2, 3],
      idOf: (i) => i,
      gridDelegate: delegate,
      actions: const [],
      onActionCompleted: () {},
      onRefresh: () async {},
      itemBuilder: (context, item, selected, onToggle) =>
          Text('item-$item${selected ? '-selected' : ''}'),
    )));

    await tester.longPress(find.text('item-1'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.text('1 selected'), findsNothing);
    expect(find.text('item-1-selected'), findsNothing);
  });
}
