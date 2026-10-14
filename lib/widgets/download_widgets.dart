import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/downloads_service.dart';
import '../theme/spotify_theme.dart';

/// Circular "download all" button for a list of songs (Spotify-style):
/// arrow when nothing is saved, a progress ring while the queue runs,
/// a filled check when every song is offline.
class DownloadAllButton extends StatelessWidget {
  const DownloadAllButton({super.key, required this.songs, this.size = 30});

  final List<Song> songs;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dl = DownloadsService();
    return ValueListenableBuilder<Set<String>>(
      valueListenable: dl.downloadedIds,
      builder: (context, _, __) => ValueListenableBuilder<Map<String, int>>(
        valueListenable: dl.progress,
        builder: (context, prog, __) {
          if (songs.isEmpty) return const SizedBox.shrink();
          final done = songs.where((s) => dl.isDownloaded(s.id)).length;
          final active = songs.where((s) => prog.containsKey(s.id)).length;
          final all = done == songs.length;
          final IconData icon;
          final Color color;
          String tip;
          if (all) {
            icon = Icons.download_done_rounded;
            color = SpotifyColors.green;
            tip = 'All ${songs.length} downloaded';
          } else if (active > 0) {
            icon = Icons.close_rounded;
            color = SpotifyColors.textPrimary;
            tip = 'Downloading $done/${songs.length} · tap to stop';
          } else {
            icon = Icons.arrow_circle_down_rounded;
            color = SpotifyColors.textSecondary;
            tip = done > 0
                ? 'Download the other ${songs.length - done}'
                : 'Download all ${songs.length}';
          }
          return Tooltip(
            message: tip,
            child: InkResponse(
              radius: size,
              onTap: () {
                final messenger = ScaffoldMessenger.maybeOf(context);
                if (all) {
                  messenger?.showSnackBar(
                      SnackBar(content: Text('All songs are offline')));
                  return;
                }
                if (active > 0) {
                  dl.cancelQueue();
                  messenger?.showSnackBar(
                      const SnackBar(content: Text('Stopped downloads')));
                  return;
                }
                final n = dl.queue(songs);
                messenger?.showSnackBar(SnackBar(
                    content: Text(n == 0
                        ? 'Already downloading'
                        : 'Downloading $n songs for offline')));
              },
              child: SizedBox(
                width: size + 8,
                height: size + 8,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (active > 0)
                      SizedBox(
                        width: size + 4,
                        height: size + 4,
                        child: CircularProgressIndicator(
                          value: songs.isEmpty ? 0 : done / songs.length,
                          strokeWidth: 2.5,
                          color: SpotifyColors.green,
                          backgroundColor: SpotifyColors.surfaceLighter,
                        ),
                      ),
                    Icon(icon,
                        color: color, size: active > 0 ? size * 0.6 : size),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Small green arrow shown next to a song that is available offline.
class DownloadedBadge extends StatelessWidget {
  const DownloadedBadge({super.key, required this.songId});
  final String songId;

  @override
  Widget build(BuildContext context) {
    final dl = DownloadsService();
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: dl.progress,
      builder: (context, prog, _) => ValueListenableBuilder<Set<String>>(
        valueListenable: dl.downloadedIds,
        builder: (context, _, __) {
          final p = prog[songId];
          if (p != null) {
            return SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                value: p == 0 ? null : p / 100,
                strokeWidth: 2,
                color: SpotifyColors.green,
              ),
            );
          }
          if (!dl.isDownloaded(songId)) return const SizedBox.shrink();
          return Icon(Icons.arrow_circle_down_rounded,
              size: 15, color: SpotifyColors.green);
        },
      ),
    );
  }
}
