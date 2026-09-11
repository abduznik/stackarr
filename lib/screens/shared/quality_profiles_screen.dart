import 'package:flutter/material.dart';
import '../../models/quality_profile.dart';
import '../../services/arr/servarr_client.dart';

/// View + simple-edit screen for quality profiles, shared by Radarr,
/// Sonarr, and Lidarr since `/qualityprofile` is identical across all
/// three (see ServarrClient.getQualityProfiles/updateQualityProfile).
///
/// Editing is intentionally limited to what's safe without
/// reconstructing the full nested quality-group structure: rename,
/// toggle upgrade-allowed, and change the upgrade cutoff among the
/// profile's own allowed qualities. New profiles are created by
/// duplicating an existing one (server assigns a new id) rather than
/// through a from-scratch quality-group picker — editing which
/// qualities belong to which group stays a web-UI-only task, that
/// structure is deep enough to warrant its own dedicated builder.
class QualityProfilesScreen extends StatefulWidget {
  final ServarrClient client;

  const QualityProfilesScreen({super.key, required this.client});

  @override
  State<QualityProfilesScreen> createState() => _QualityProfilesScreenState();
}

class _QualityProfilesScreenState extends State<QualityProfilesScreen> {
  late Future<List<QualityProfile>> _profilesFuture;

  @override
  void initState() {
    super.initState();
    _profilesFuture = _load();
  }

  Future<List<QualityProfile>> _load() async {
    final raw = await widget.client.getQualityProfiles();
    return raw
        .map((e) => QualityProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _reload() {
    setState(() {
      _profilesFuture = _load();
    });
  }

  Future<void> _editProfile(QualityProfile profile) async {
    final nameController = TextEditingController(text: profile.name);
    bool upgradeAllowed = profile.upgradeAllowed;
    int cutoff = profile.cutoff;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit quality profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              if (profile.items.any((i) => i.qualityId != null))
                DropdownButtonFormField<int>(
                  initialValue: cutoff,
                  decoration: const InputDecoration(labelText: 'Upgrade until'),
                  items: [
                    for (final item in profile.items)
                      if (item.qualityId != null)
                        DropdownMenuItem(
                          value: item.qualityId,
                          child: Text(item.name),
                        ),
                  ],
                  onChanged: (v) => setDialogState(() => cutoff = v!),
                ),
              CheckboxListTile(
                value: upgradeAllowed,
                title: const Text('Allow upgrades'),
                onChanged: (v) =>
                    setDialogState(() => upgradeAllowed = v ?? false),
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    try {
      await widget.client.updateQualityProfile(
        profile.id,
        profile.toUpdatedJson(
          name: nameController.text.trim(),
          upgradeAllowed: upgradeAllowed,
          cutoff: cutoff,
        ),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  Future<void> _duplicateProfile(QualityProfile profile) async {
    final nameController =
        TextEditingController(text: '${profile.name} (copy)');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicate profile'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New profile name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.client.createQualityProfile(
        profile.toUpdatedJson(name: nameController.text.trim()),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create: $e')),
      );
    }
  }

  Future<void> _deleteProfile(QualityProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${profile.name}"?'),
        content: const Text(
            'Any movies/series/artists using this profile will need to be '
            'reassigned. The server will reject this if the profile is '
            'still in use.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.client.deleteQualityProfile(profile.id);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quality Profiles')),
      body: FutureBuilder<List<QualityProfile>>(
        future: _profilesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final profiles = snapshot.data ?? [];
          if (profiles.isEmpty) {
            return const Center(
              child: Text(
                'No quality profiles found.\nCreate at least one from the '
                'server\'s web UI first — this screen can only duplicate an '
                'existing profile.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              final allowedCount = profile.items.where((i) => i.allowed).length;
              return ListTile(
                title: Text(profile.name),
                subtitle: Text(
                  '$allowedCount allowed quality(ies)'
                  '${profile.cutoffName != null ? ' · upgrade until ${profile.cutoffName}' : ''}'
                  '${profile.upgradeAllowed ? '' : ' · upgrades disabled'}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editProfile(profile);
                      case 'duplicate':
                        _duplicateProfile(profile);
                      case 'delete':
                        _deleteProfile(profile);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
