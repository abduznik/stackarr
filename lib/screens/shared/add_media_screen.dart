import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Generic "search and add to library" screen shared by Radarr/Sonarr/
/// Lidarr — their lookup/add/qualityProfile/rootFolder APIs all follow the
/// same shape (see RadarrClient.lookupMovie/addMovie, SonarrClient's
/// lookupSeries/addSeries, LidarrClient's lookupArtist/addArtist), so one
/// UI driven by callbacks avoids three near-identical screens.
///
/// [posterUrlOf] and [titleOf] extract display fields from a raw lookup
/// result Map (its shape varies slightly per service), [alreadyAdded]
/// flags results whose id already exists in the local library so they
/// render as "In library" instead of an Add button.
class AddMediaScreen extends StatefulWidget {
  final String serviceLabel;
  final Future<List<dynamic>> Function(String term) onSearch;
  final Future<List<dynamic>> Function() onLoadQualityProfiles;
  final Future<List<dynamic>> Function() onLoadRootFolders;
  final Future<void> Function({
    required Map<String, dynamic> lookupResult,
    required int qualityProfileId,
    required String rootFolderPath,
    required bool monitored,
    required bool searchOnAdd,
  }) onAdd;
  final String Function(Map<String, dynamic> result) titleOf;
  final String? Function(Map<String, dynamic> result) posterUrlOf;
  final bool Function(Map<String, dynamic> result) alreadyAdded;

  const AddMediaScreen({
    super.key,
    required this.serviceLabel,
    required this.onSearch,
    required this.onLoadQualityProfiles,
    required this.onLoadRootFolders,
    required this.onAdd,
    required this.titleOf,
    required this.posterUrlOf,
    required this.alreadyAdded,
  });

  @override
  State<AddMediaScreen> createState() => _AddMediaScreenState();
}

class _AddMediaScreenState extends State<AddMediaScreen> {
  final _searchController = TextEditingController();
  List<dynamic>? _results;
  bool _searching = false;
  String? _searchError;

  List<dynamic> _qualityProfiles = [];
  List<dynamic> _rootFolders = [];
  bool _optionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final profiles = await widget.onLoadQualityProfiles();
      final folders = await widget.onLoadRootFolders();
      if (!mounted) return;
      setState(() {
        _qualityProfiles = profiles;
        _rootFolders = folders;
        _optionsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _optionsLoaded = true);
    }
  }

  Future<void> _search(String term) async {
    if (term.trim().isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await widget.onSearch(term.trim());
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = e.toString();
        _searching = false;
      });
    }
  }

  Future<void> _showAddDialog(Map<String, dynamic> result) async {
    if (_qualityProfiles.isEmpty || _rootFolders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No quality profiles or root folders configured on the server')),
      );
      return;
    }

    int selectedProfileId = _qualityProfiles.first['id'] as int;
    String selectedRootFolder = _rootFolders.first['path'] as String;
    bool monitored = true;
    bool searchOnAdd = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Add "${widget.titleOf(result)}"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedProfileId,
                decoration: const InputDecoration(labelText: 'Quality profile'),
                items: [
                  for (final p in _qualityProfiles)
                    DropdownMenuItem(
                      value: p['id'] as int,
                      child: Text(p['name'] as String),
                    ),
                ],
                onChanged: (v) => setDialogState(() => selectedProfileId = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedRootFolder,
                decoration: const InputDecoration(labelText: 'Root folder'),
                items: [
                  for (final f in _rootFolders)
                    DropdownMenuItem(
                      value: f['path'] as String,
                      child: Text(f['path'] as String,
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setDialogState(() => selectedRootFolder = v!),
              ),
              CheckboxListTile(
                value: monitored,
                title: const Text('Monitored'),
                onChanged: (v) => setDialogState(() => monitored = v ?? true),
              ),
              CheckboxListTile(
                value: searchOnAdd,
                title: const Text('Search on add'),
                onChanged: (v) => setDialogState(() => searchOnAdd = v ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.onAdd(
        lookupResult: result,
        qualityProfileId: selectedProfileId,
        rootFolderPath: selectedRootFolder,
        monitored: monitored,
        searchOnAdd: searchOnAdd,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added "${widget.titleOf(result)}"')),
      );
      setState(() {}); // refresh alreadyAdded state for this result
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add to ${widget.serviceLabel}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)))
                    : null,
              ),
              onSubmitted: _search,
              textInputAction: TextInputAction.search,
            ),
          ),
          if (!_optionsLoaded)
            const LinearProgressIndicator()
          else if (_qualityProfiles.isEmpty || _rootFolders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Warning: could not load quality profiles or root folders '
                'from the server.',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_searchError!,
                  style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _results == null
                ? const Center(child: Text('Search to find something to add'))
                : _results!.isEmpty
                    ? const Center(child: Text('No results'))
                    : ListView.builder(
                        itemCount: _results!.length,
                        itemBuilder: (context, index) {
                          final result =
                              _results![index] as Map<String, dynamic>;
                          final poster = widget.posterUrlOf(result);
                          final added = widget.alreadyAdded(result);

                          return ListTile(
                            leading: SizedBox(
                              width: 40,
                              height: 56,
                              child: poster != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: CachedNetworkImage(
                                        imageUrl: poster,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            const ColoredBox(
                                                color: Colors.black12),
                                      ),
                                    )
                                  : const ColoredBox(color: Colors.black12),
                            ),
                            title: Text(widget.titleOf(result)),
                            trailing: added
                                ? const Chip(label: Text('In library'))
                                : FilledButton(
                                    onPressed: () => _showAddDialog(result),
                                    child: const Text('Add'),
                                  ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
