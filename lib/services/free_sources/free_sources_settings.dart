import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/spotify_theme.dart';
import 'free_sources.dart';

/// Settings → Driving → Free music sources: switches and optional keys.
class FreeSourcesSettingsScreen extends StatefulWidget {
  const FreeSourcesSettingsScreen({super.key});

  @override
  State<FreeSourcesSettingsScreen> createState() =>
      _FreeSourcesSettingsScreenState();
}

class _FreeSourcesSettingsScreenState extends State<FreeSourcesSettingsScreen> {
  final _fs = FreeSources.instance;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _fs.load().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  Future<void> _editKey(FreeMusicSource s) async {
    final ctrl = TextEditingController(text: _fs.keyFor(s.id));
    final saved = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${s.name} key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.needsKey
                  ? 'Paste the free client id from your ${s.name} developer account.'
                  : 'Optional. Paste a free API key for higher rate limits.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: SpotifyColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Key'),
            ),
            if (s.keyUrl != null)
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(s.keyUrl!),
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Get a free key'),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(c).pop(ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved != null) {
      await _fs.setKey(s.id, saved);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.background,
      appBar: AppBar(title: const Text('Free music sources')),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<Map<String, bool>>(
              valueListenable: _fs.enabled,
              builder: (context, on, _) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                    child: Text(
                      'These catalogues are free and legal to stream — artists '
                      'publish there for free listening, or the music is '
                      'Creative Commons / public domain. They show up in Search, '
                      'on the Free Music page and in Android Auto.',
                      style: TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontSize: 13.5,
                          height: 1.4),
                    ),
                  ),
                  for (final s in _fs.all) ...[
                    _tile(s, on[s.id] ?? true),
                    const SizedBox(height: 10),
                  ],
                  _radioTile(),
                ],
              ),
            ),
    );
  }

  Widget _tile(FreeMusicSource s, bool enabled) {
    final key = _fs.keyFor(s.id);
    final missingKey = s.needsKey && key.isEmpty;
    return Material(
      color: SpotifyColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: TextStyle(
                              color: SpotifyColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(s.blurb,
                          style: TextStyle(
                              color: SpotifyColors.textSecondary,
                              fontSize: 13)),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: (v) => _fs.setEnabled(s.id, v),
                ),
              ],
            ),
            if (s.needsKey || s.keyUrl != null)
              TextButton.icon(
                onPressed: () => _editKey(s),
                icon: Icon(
                  missingKey ? Icons.key_off_rounded : Icons.key_rounded,
                  size: 18,
                ),
                label: Text(missingKey
                    ? 'Add free key to enable'
                    : key.isEmpty
                        ? 'Add API key (optional)'
                        : 'Key saved · change'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _radioTile() {
    return Material(
      color: SpotifyColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
        title: Text('Radio Browser',
            style: TextStyle(
                color: SpotifyColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        subtitle: Text('50,000+ internet radio stations · always on',
            style:
                TextStyle(color: SpotifyColors.textSecondary, fontSize: 13)),
        trailing: Icon(Icons.radio_rounded, color: SpotifyColors.green),
      ),
    );
  }
}
