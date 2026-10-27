import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/app_services.dart';

/// Mock of "community contribution": Deaf users suggest regional variations
/// of signs. PROTOTYPE ONLY: entries are saved on this device and go
/// nowhere. A real version needs Deaf-led review, informed consent, video
/// handling rules, and a backend (and the data-privacy law checked).
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  static const _key = 'contributions_v1';

  final TextEditingController _region = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  List<Map<String, dynamic>> _saved = [];
  String? _gloss;
  bool _consent = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _region.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final raw = await widget.services.store.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) setState(() => _saved = list);
    } catch (_) {
      // Ignore unreadable data in this prototype.
    }
  }

  Future<void> _persist() =>
      widget.services.store.setString(_key, jsonEncode(_saved));

  bool get _canSubmit =>
      _gloss != null && _region.text.trim().isNotEmpty && _consent;

  Future<void> _submit() async {
    _saved.insert(0, {
      'gloss': _gloss,
      'region': _region.text.trim(),
      'notes': _notes.text.trim(),
    });
    await _persist();
    if (!mounted) return;
    setState(() {
      _gloss = null;
      _consent = false;
      _region.clear();
      _notes.clear();
    });
  }

  Future<void> _delete(int i) async {
    _saved.removeAt(i);
    await _persist();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glosses = [for (final s in widget.services.vocab.signs) s.gloss];

    return Scaffold(
      appBar: AppBar(title: const Text('Community contribution')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Prototype only. Suggestions are saved on this phone and are '
              'not sent anywhere. No video or photos.',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _gloss,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Which sign?',
            ),
            items: [
              for (final g in glosses)
                DropdownMenuItem(value: g, child: Text(g)),
            ],
            onChanged: (v) => setState(() => _gloss = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _region,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Region or community (e.g. Cebu)',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'How is it signed differently?',
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            title: const Text(
              'I agree to share this to improve the app (you can delete it '
              'any time).',
            ),
          ),
          FilledButton(
            onPressed: _canSubmit ? _submit : null,
            child: const Text('Save suggestion'),
          ),
          const SizedBox(height: 16),
          Text('Saved here', style: Theme.of(context).textTheme.titleMedium),
          if (_saved.isEmpty) const Text('Nothing yet.'),
          for (var i = 0; i < _saved.length; i++)
            Card(
              child: ListTile(
                title: Text('${_saved[i]['gloss']} · ${_saved[i]['region']}'),
                subtitle: Text('${_saved[i]['notes']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(i),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
