import 'package:flutter/material.dart';

/// One bulk action offered when items are selected — Monitor/Unmonitor/
/// Search/Delete, each service wires its own callback since the
/// underlying bulk API differs (movieIds vs seriesIds vs artistIds).
class BulkAction {
  final IconData icon;
  final String label;
  final bool destructive;
  final Future<void> Function(List<int> selectedIds) onRun;

  const BulkAction({
    required this.icon,
    required this.label,
    required this.onRun,
    this.destructive = false,
  });
}

/// Wraps a library grid with long-press-to-select multi-select behavior,
/// shared by Movies/TV/Music screens since the interaction is identical:
/// long-press enters selection mode, tap toggles a tile's selection while
/// selecting, and a contextual app bar with [actions] appears above the
/// grid once anything is selected.
///
/// [itemBuilder] receives the item, whether it's selected, and a toggle
/// callback — it owns rendering the selection affordance (e.g. a checkmark
/// overlay) so this widget stays grid-shape-agnostic.
class SelectableGrid<T> extends StatefulWidget {
  final List<T> items;
  final int Function(T item) idOf;
  final Widget Function(
    BuildContext context,
    T item,
    bool selected,
    VoidCallback onToggle,
  ) itemBuilder;
  final SliverGridDelegate gridDelegate;
  final List<BulkAction> actions;
  final VoidCallback onActionCompleted;
  final Future<void> Function() onRefresh;

  /// Called on tap when nothing is selected — e.g. opening a detail
  /// screen. Ignored while selection mode is active, where tap toggles
  /// selection instead.
  final void Function(T item)? onTapItem;

  const SelectableGrid({
    super.key,
    required this.items,
    required this.idOf,
    required this.itemBuilder,
    required this.gridDelegate,
    required this.actions,
    required this.onActionCompleted,
    required this.onRefresh,
    this.onTapItem,
  });

  @override
  State<SelectableGrid<T>> createState() => _SelectableGridState<T>();
}

class _SelectableGridState<T> extends State<SelectableGrid<T>> {
  final Set<int> _selectedIds = {};

  bool get _isSelecting => _selectedIds.isNotEmpty;

  void _toggle(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _runAction(BulkAction action) async {
    final ids = _selectedIds.toList();
    if (action.destructive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(action.label),
          content: Text('Apply "${action.label}" to ${ids.length} item(s)?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(action.label),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await action.onRun(ids);
      setState(() => _selectedIds.clear());
      widget.onActionCompleted();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isSelecting)
          Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel selection',
                    onPressed: () => setState(() => _selectedIds.clear()),
                  ),
                  Text('${_selectedIds.length} selected'),
                  const Spacer(),
                  for (final action in widget.actions)
                    IconButton(
                      icon: Icon(action.icon),
                      tooltip: action.label,
                      color: action.destructive
                          ? Theme.of(context).colorScheme.error
                          : null,
                      onPressed: () => _runAction(action),
                    ),
                ],
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: widget.gridDelegate,
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final id = widget.idOf(item);
                final selected = _selectedIds.contains(id);
                return GestureDetector(
                  onLongPress: () => _toggle(id),
                  onTap: _isSelecting
                      ? () => _toggle(id)
                      : widget.onTapItem != null
                          ? () => widget.onTapItem!(item)
                          : null,
                  child: widget.itemBuilder(
                    context,
                    item,
                    selected,
                    () => _toggle(id),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
