import 'package:flutter/material.dart';

/// A search icon that expands into a text field for filtering an
/// already-loaded list by title — distinct from AddMediaScreen's search,
/// which queries the server's /lookup endpoint for new things to add.
/// This one is purely client-side and generic: any screen that has a
/// `List<T>` and a way to extract a title string from each `T` can use
/// it, so the same widget covers movies, series, artists, indexers,
/// torrents, and requests without per-service duplication.
class LibrarySearchBar extends StatefulWidget {
  final ValueChanged<String> onQueryChanged;
  final String hintText;

  const LibrarySearchBar({
    super.key,
    required this.onQueryChanged,
    this.hintText = 'Search...',
  });

  @override
  State<LibrarySearchBar> createState() => _LibrarySearchBarState();
}

class _LibrarySearchBarState extends State<LibrarySearchBar> {
  bool _expanded = false;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _focusNode.requestFocus();
    } else {
      _controller.clear();
      widget.onQueryChanged('');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return IconButton(
        icon: const Icon(Icons.search),
        tooltip: 'Search',
        onPressed: _toggle,
      );
    }
    return SizedBox(
      width: 220,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: widget.hintText,
          isDense: true,
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _toggle,
          ),
        ),
        onChanged: widget.onQueryChanged,
      ),
    );
  }
}

/// Case-insensitive substring filter — the shared matching logic behind
/// every screen's search bar, pulled out so it's unit-testable without
/// standing up a widget.
List<T> filterByTitle<T>(
  List<T> items,
  String query,
  String Function(T item) titleOf,
) {
  if (query.trim().isEmpty) return items;
  final needle = query.trim().toLowerCase();
  return items
      .where((item) => titleOf(item).toLowerCase().contains(needle))
      .toList();
}
