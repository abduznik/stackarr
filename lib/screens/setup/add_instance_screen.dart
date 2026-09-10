import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/instance_config.dart';
import '../../models/service_type.dart';
import '../../providers/instance_providers.dart';
import '../../services/arr/service_client_factory.dart';

/// Connection form for one service: URL + credentials, with a live
/// "Test Connection" health check before saving. Reused by both the setup
/// wizard (first run) and Settings (adding another instance later).
class AddInstanceScreen extends ConsumerStatefulWidget {
  final ServiceType serviceType;

  const AddInstanceScreen({super.key, required this.serviceType});

  @override
  ConsumerState<AddInstanceScreen> createState() => _AddInstanceScreenState();
}

enum _CheckState { idle, checking, success, failure }

class _AddInstanceScreenState extends ConsumerState<AddInstanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _urlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  _CheckState _checkState = _CheckState.idle;
  String? _checkError;
  bool _saving = false;

  bool get _usesCredentialPair => widget.serviceType == ServiceType.qbittorrent;

  @override
  void initState() {
    super.initState();
    _labelController.text = widget.serviceType.label;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _checkState = _CheckState.checking;
      _checkError = null;
    });
    try {
      final ok = await ServiceClientFactory.checkHealth(
        type: widget.serviceType,
        baseUrl: _urlController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      );
      setState(() {
        _checkState = ok ? _CheckState.success : _CheckState.failure;
        _checkError = ok ? null : 'Could not verify the connection.';
      });
    } catch (e) {
      setState(() {
        _checkState = _CheckState.failure;
        _checkError = e.toString();
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final config = InstanceConfig(
      id: const Uuid().v4(),
      type: widget.serviceType,
      label: _labelController.text.trim(),
      baseUrl: _urlController.text.trim(),
    );

    final secret = _usesCredentialPair
        ? '${_usernameController.text.trim()}:${_passwordController.text.trim()}'
        : _apiKeyController.text.trim();

    final repo = ref.read(instanceRepositoryProvider);
    await repo.save(config, secret);
    ref.invalidate(instancesProvider);

    if (mounted) Navigator.of(context).pop(config);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Connect ${widget.serviceType.label}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Instance name',
                helperText: 'e.g. "Home Lab" — shown in the sidebar',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://192.168.1.10:${_defaultPort()}',
              ),
              keyboardType: TextInputType.url,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final uri = Uri.tryParse(v.trim());
                if (uri == null || !uri.hasScheme) {
                  return 'Include http:// or https://';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            if (_usesCredentialPair) ...[
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ] else ...[
              TextFormField(
                controller: _apiKeyController,
                decoration: InputDecoration(
                  labelText: widget.serviceType == ServiceType.aria2
                      ? 'RPC secret (optional)'
                      : 'API key',
                ),
                obscureText: true,
                validator: (v) {
                  if (widget.serviceType == ServiceType.aria2) return null;
                  return (v == null || v.trim().isEmpty) ? 'Required' : null;
                },
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed:
                  _checkState == _CheckState.checking ? null : _testConnection,
              icon: _checkState == _CheckState.checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(switch (_checkState) {
                      _CheckState.success => Icons.check_circle,
                      _CheckState.failure => Icons.error,
                      _ => Icons.wifi_tethering,
                    }),
              label: const Text('Test Connection'),
            ),
            if (_checkState == _CheckState.success)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Connected successfully',
                    style: TextStyle(color: Colors.green)),
              ),
            if (_checkState == _CheckState.failure && _checkError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_checkError!,
                    style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _defaultPort() => switch (widget.serviceType) {
        ServiceType.radarr => '7878',
        ServiceType.sonarr => '8989',
        ServiceType.lidarr => '8686',
        ServiceType.prowlarr => '9696',
        ServiceType.bazarr => '6767',
        ServiceType.qbittorrent => '8080',
        ServiceType.aria2 => '6800',
        ServiceType.jellyseerr => '5055',
      };
}
