import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../models/song.dart';
import '../screens/car_mode_screen.dart';
import '../screens/downloads_screen.dart';
import '../screens/import_spotify_screen.dart';
import '../screens/free_music_screen.dart';
import '../screens/liked_songs_screen.dart';
import '../screens/listen_together_screen.dart';
import '../screens/radio_screen.dart';
import '../services/free_sources/free_sources.dart';
import '../theme/spotify_theme.dart';

/// Top of the Home tab in a Spotify-like layout: time-of-day greeting
/// with quick actions, filter chips, then a 2-column "quick picks" grid.
class SpotifyHomeHeader extends StatelessWidget {
  const SpotifyHomeHeader({
    super.key,
    required this.recent,
    required this.onOpenSettings,
  });

  final List<Song> recent;
  final VoidCallback onOpenSettings;

  static String greeting([DateTime? now]) {
    final h = (now ?? DateTime.now()).hour;
    if (h >= 5 && h < 12) return 'Good morning';
    if (h >= 12 && h < 17) return 'Good afternoon';
    if (h >= 17 && h < 22) return 'Good evening';
    return 'Late night vibes';
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  greeting(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: SpotifyColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              _HeaderIcon(
                icon: Icons.directions_car_outlined,
                tooltip: 'Car Mode',
                onTap: () => _push(context, const CarModeScreen()),
              ),
              _HeaderIcon(
                icon: Icons.people_outline_rounded,
                tooltip: 'Listen together',
                onTap: () => _push(context, const ListenTogetherScreen()),
              ),
              _HeaderIcon(
                icon: Icons.settings_outlined,
                tooltip: 'Settings',
                onTap: onOpenSettings,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            children: [
              _Chip('Free music', Icons.public_rounded,
                  () => _push(context, const FreeMusicScreen())),
              _Chip('Radio', Icons.radio_rounded,
                  () => _push(context, const RadioScreen())),
              _Chip('Liked', Icons.favorite_rounded,
                  () => _push(context, const LikedSongsScreen())),
              _Chip('Downloads', Icons.download_for_offline_rounded,
                  () => _push(context, const DownloadsScreen())),
              _Chip('Import from Spotify', Icons.playlist_add_rounded,
                  () => _push(context, const ImportSpotifyScreen())),
              _Chip('Car Mode', Icons.directions_car_rounded,
                  () => _push(context, const CarModeScreen())),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _QuickPicks(recent: recent),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: SpotifyColors.textPrimary, size: 26),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: SpotifyColors.surfaceLight,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: SpotifyColors.highlight),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: SpotifyColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 2×N grid of compact tiles: Liked Songs first, then recent tracks.
class _QuickPicks extends StatelessWidget {
  const _QuickPicks({required this.recent});
  final List<Song> recent;

  @override
  Widget build(BuildContext context) {
    final liked = storage.getLikedSongs();
    final picks = recent.take(liked.isEmpty ? 6 : 5).toList();
    final tiles = <Widget>[
      if (liked.isNotEmpty)
        _PickTile(
          title: 'Liked Songs',
          leading: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [SpotifyColors.greenDark, SpotifyColors.highlight],
              ),
            ),
            child: const Icon(Icons.favorite_rounded,
                color: Colors.white, size: 24),
          ),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const LikedSongsScreen())),
        ),
      for (var i = 0; i < picks.length; i++)
        _PickTile(
          title: picks[i].title,
          leading: picks[i].thumbnail.isEmpty
              ? Container(color: SpotifyColors.surfaceLighter)
              : CachedNetworkImage(
                  imageUrl: picks[i].thumbnail,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: SpotifyColors.surfaceLighter),
                ),
          onTap: () => audioHandler.setQueue(picks, startIndex: i),
        ),
    ];
    if (tiles.isEmpty) return const _EmptyPicks();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.1,
        padding: EdgeInsets.zero,
        children: tiles,
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile(
      {required this.title, required this.leading, required this.onTap});
  final String title;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SpotifyColors.surfaceLight,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            AspectRatio(aspectRatio: 1, child: leading),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: SpotifyColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _EmptyPicks extends StatelessWidget {
  const _EmptyPicks();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Text(
        'Play something and your quick picks will show up here.',
        style: TextStyle(color: SpotifyColors.textTertiary, fontSize: 13),
      ),
    );
  }
}

/// Horizontal shelf of trending tracks from the first active free
/// source (Audius by default). Loads independently of the main feed.
class FreeMusicShelf extends StatefulWidget {
  const FreeMusicShelf({super.key});

  @override
  State<FreeMusicShelf> createState() => _FreeMusicShelfState();
}

class _FreeMusicShelfState extends State<FreeMusicShelf> {
  late final Future<(FreeMusicSource?, List<Song>)> _future = _load();

  Future<(FreeMusicSource?, List<Song>)> _load() async {
    await FreeSources.instance.load();
    for (final s in FreeSources.instance.active) {
      try {
        final songs = await s.trending(limit: 15);
        if (songs.isNotEmpty) return (s, songs);
      } catch (_) {}
    }
    return (null, const <Song>[]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(FreeMusicSource?, List<Song>)>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null || data.$2.isEmpty) return const SizedBox.shrink();
        final (src, songs) = data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Free & independent',
                            style: TextStyle(
                                color: SpotifyColors.textPrimary,
                                fontSize: 21,
                                fontWeight: FontWeight.w800)),
                        Text('Trending on ${src?.name ?? ''}',
                            style: TextStyle(
                                color: SpotifyColors.textSecondary,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const FreeMusicScreen())),
                    child: const Text('Show all'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 196,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: songs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final s = songs[i];
                  return GestureDetector(
                    onTap: () => audioHandler.setQueue(songs, startIndex: i),
                    child: SizedBox(
                      width: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 140,
                              height: 140,
                              child: s.thumbnail.isEmpty
                                  ? Container(
                                      color: SpotifyColors.surfaceLight)
                                  : CachedNetworkImage(
                                      imageUrl: s.thumbnail,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                          color: SpotifyColors.surfaceLight),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: SpotifyColors.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600)),
                          Text(s.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: SpotifyColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
