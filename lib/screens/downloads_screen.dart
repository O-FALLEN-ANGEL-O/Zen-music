import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../models/song.dart';
import '../services/downloads_service.dart';
import '../theme/spotify_theme.dart';

/// Everything saved for offline, plus the live download queue.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final _dl = DownloadsService();
  List<Song> _songs = const [];
  int _bytes = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _dl.revision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _dl.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final songs = await _dl.downloadedSongs();
    final bytes = await _dl.totalBytes();
    if (!mounted) return;
    setState(() {
      _songs = songs;
      _bytes = bytes;
      _loading = false;
    });
  }

  String get _size {
    final mb = _bytes / (1024 * 1024);
    return mb >= 1024
        ? '${(mb / 1024).toStringAsFixed(1)} GB'
        : '${mb.toStringAsFixed(0)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.background,
      appBar: AppBar(title: const Text('Downloads')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 140),
              children: [
                _QueueBanner(dl: _dl),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _songs.isEmpty
                              ? 'Nothing downloaded yet'
                              : '${_songs.length} songs · $_size',
                          style: TextStyle(
                              color: SpotifyColors.textSecondary,
                              fontSize: 13.5),
                        ),
                      ),
                      if (_songs.isNotEmpty) ...[
                        IconButton(
                          tooltip: 'Shuffle',
                          icon: Icon(Icons.shuffle_rounded,
                              color: SpotifyColors.textPrimary),
                          onPressed: () => audioHandler.setQueue(
                              List<Song>.from(_songs)..shuffle()),
                        ),
                        IconButton(
                          tooltip: 'Play all',
                          iconSize: 46,
                          icon: Icon(Icons.play_circle_fill_rounded,
                              color: SpotifyColors.green),
                          onPressed: () => audioHandler.setQueue(_songs),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_songs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Tap the download arrow on Liked songs, a playlist or '
                      'any song to keep it on your phone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: SpotifyColors.textTertiary, height: 1.4),
                    ),
                  ),
                for (var i = 0; i < _songs.length; i++)
                  _row(_songs[i], i),
              ],
            ),
    );
  }

  Widget _row(Song s, int i) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 48,
          height: 48,
          child: s.thumbnail.isEmpty
              ? Container(color: SpotifyColors.surfaceLight)
              : CachedNetworkImage(
                  imageUrl: s.thumbnail,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: SpotifyColors.surfaceLight),
                ),
        ),
      ),
      title: Text(s.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: SpotifyColors.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Row(
        children: [
          Icon(Icons.arrow_circle_down_rounded,
              size: 14, color: SpotifyColors.green),
          const SizedBox(width: 4),
          Expanded(
            child: Text(s.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: SpotifyColors.textSecondary)),
          ),
        ],
      ),
      trailing: IconButton(
        tooltip: 'Remove download',
        icon: Icon(Icons.delete_outline_rounded,
            color: SpotifyColors.textTertiary),
        onPressed: () => _dl.delete(s.id),
      ),
      onTap: () => audioHandler.setQueue(_songs, startIndex: i),
    );
  }
}

class _QueueBanner extends StatelessWidget {
  const _QueueBanner({required this.dl});
  final DownloadsService dl;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: dl.progress,
      builder: (context, prog, _) {
        if (prog.isEmpty) return const SizedBox.shrink();
        final avg = prog.values.fold<int>(0, (a, b) => a + b) / prog.length;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
            color: SpotifyColors.surfaceLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  value: avg / 100,
                  strokeWidth: 2.5,
                  color: SpotifyColors.green,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text('Downloading ${prog.length} songs…',
                    style: TextStyle(
                        color: SpotifyColors.textPrimary,
                        fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: dl.cancelQueue,
                child: const Text('Stop'),
              ),
            ],
          ),
        );
      },
    );
  }
}
