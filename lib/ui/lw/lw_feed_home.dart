import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models/song.dart';
import '../../screens/listen_together_screen.dart';
import '../../services/home_service.dart';
import '../../services/storage_service.dart';
import '../../theme/spotify_theme.dart';
import 'lw_feed_section.dart';

/// FeedScreen port. Section order and geometry follow FeedScreen.kt;
/// data comes from ZenMusic's HomeService (same shelves the existing
/// HomeTab loads) + played history. Header row restores the old
/// HomeTab masthead with Listen Together + Settings entry points.
class LwFeedHome extends StatefulWidget {
  const LwFeedHome({super.key, required this.onOpenSearch, required this.onOpenSettings});
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenSettings;

  @override
  State<LwFeedHome> createState() => _LwFeedHomeState();
}

class _LwFeedHomeState extends State<LwFeedHome> {
  final _homeService = HomeService();
  List<Song> _biggestHits = [];
  List<Song> _trendingNow = [];
  List<Song> _ytmHot = [];
  List<Song> _ytmFresh = [];
  List<Song> _topCharts = [];
  List<Song> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _homeService.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final hits = _homeService.getBiggestHits();
      final trending = _homeService.getTrendingNow();
      final hot = _homeService.getYtmShelf('top hits this week');
      final fresh = _homeService.getYtmShelf('new music this week', limit: 12);
      final charts = _homeService.getTopCharts();
      _biggestHits = await hits;
      _trendingNow = await trending;
      _ytmHot = await hot;
      _ytmFresh = await fresh;
      _topCharts = await charts;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _recent = storage.getPlayedHistory().take(12).toList();
      _loading = false;
    });
  }

  void _playQueue(List<Song> songs, int index) {
    if (songs.isEmpty) return;
    audioHandler.setQueue(songs, startIndex: index);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(
          child: CircularProgressIndicator(color: SpotifyColors.highlight))
          : ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 190),
        children: [
          // Header row: masthead + Listen Together + Settings — the
          // old HomeTab header entry points, restored.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'ZenMusic',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: SpotifyColors.textPrimary,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Retro Blendy',
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ListenTogetherScreen()));
                  },
                  child: const _RingedCircle(icon: Icons.people_outline),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: widget.onOpenSettings,
                  child: const _RingedCircle(icon: Icons.settings_outlined),
                ),
              ],
            ),
          ),
          _InfiniteRadioHero(
            seed: _biggestHits.isNotEmpty
                ? _biggestHits.first
                : (_trendingNow.isNotEmpty ? _trendingNow.first : null),
            onPlay: () {
              final seed = _biggestHits.isNotEmpty
                  ? _biggestHits.first
                  : _trendingNow.firstOrNull;
              if (seed != null) audioHandler.startRadio(seed);
            },
          ),
          const SizedBox(height: 24),
          // Jump back in (played history) — RecentTrackCard row:
          // 148dp squares, ago badge top-left.
          if (_recent.isNotEmpty) ...[
            LwFeedSectionHeader(
                title: 'Jump back in',
                subtitle: 'From your listening history',
                actionText: 'Play all',
                actionIcon: Icons.play_arrow_rounded,
                onAction: () => _playQueue(_recent, 0)),
            const SizedBox(height: 12),
            SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _recent.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => LwMediaCard(
                  songId: _recent[i].id,
                  artworkUrl: _recent[i].thumbnail,
                  title: _recent[i].title,
                  subtitle: _recent[i].artist,
                  onTap: () => _playQueue(_recent, i),
                  onPlay: () => _playQueue(_recent, i),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_biggestHits.isNotEmpty) ...[
            LwSectionCard(
              child: Column(children: [
                LwFeedSectionHeader(
                    title: 'Popular right now',
                    subtitle: 'Most popular right now · tap a rank to play',
                    actionText: 'Play all',
                    actionIcon: Icons.play_arrow_rounded,
                    onAction: () => _playQueue(_biggestHits, 0),
                    onShuffle: () => _playQueue(
                        List<Song>.from(_biggestHits)..shuffle(), 0)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _biggestHits.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => LwMediaCard(
                      songId: _biggestHits[i].id,
                      artworkUrl: _biggestHits[i].thumbnail,
                      title: _biggestHits[i].title,
                      subtitle: _biggestHits[i].artist,
                      onTap: () => _playQueue(_biggestHits, i),
                      onPlay: () => _playQueue(_biggestHits, i),
                    ),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          if (_ytmHot.isNotEmpty) ...[
            LwSectionCard(
              child: Column(children: [
                LwFeedSectionHeader(
                    title: 'Hot on YouTube Music',
                    actionText: 'Play all',
                    actionIcon: Icons.play_arrow_rounded,
                    onAction: () => _playQueue(_ytmHot, 0)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _ytmHot.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => LwMediaCard(
                      songId: _ytmHot[i].id,
                      artworkUrl: _ytmHot[i].thumbnail,
                      title: _ytmHot[i].title,
                      subtitle: _ytmHot[i].artist,
                      onTap: () => _playQueue(_ytmHot, i),
                      onPlay: () => _playQueue(_ytmHot, i),
                    ),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          if (_topCharts.isNotEmpty) ...[
            LwSectionCard(
              child: Column(children: [
                LwFeedSectionHeader(
                    title: 'Trending now',
                    subtitle: 'Most popular right now',
                    actionText: 'Play all',
                    actionIcon: Icons.play_arrow_rounded,
                    onAction: () => _playQueue(_topCharts, 0)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _topCharts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => LwMediaCard(
                      songId: _topCharts[i].id,
                      artworkUrl: _topCharts[i].thumbnail,
                      title: _topCharts[i].title,
                      subtitle: _topCharts[i].artist,
                      onTap: () => _playQueue(_topCharts, i),
                      onPlay: () => _playQueue(_topCharts, i),
                    ),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          if (_ytmFresh.isNotEmpty) ...[
            LwSectionCard(
              child: Column(children: [
                LwFeedSectionHeader(
                    title: 'Fresh finds',
                    subtitle: 'New tracks beyond your usual rotation',
                    actionText: 'Play all',
                    actionIcon: Icons.play_arrow_rounded,
                    onAction: () => _playQueue(_ytmFresh, 0)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _ytmFresh.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => LwMediaCard(
                      songId: _ytmFresh[i].id,
                      artworkUrl: _ytmFresh[i].thumbnail,
                      title: _ytmFresh[i].title,
                      subtitle: _ytmFresh[i].artist,
                      badgeText: 'NEW',
                      onTap: () => _playQueue(_ytmFresh, i),
                      onPlay: () => _playQueue(_ytmFresh, i),
                    ),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: Text('Made for you from your taste',
                style: TextStyle(
                  fontSize: 12,
                  color: SpotifyColors.textTertiary,
                )),
          ),
        ],
      ),
    );
  }
}

/// InfiniteRadioHero port: r28 card, blurred art backdrop @0.32 alpha,
/// primary-tinted vertical gradient, MADE FOR YOU pill, 24sp ExtraBold
/// title, 44dp stadium Play with centered content.
class _InfiniteRadioHero extends StatelessWidget {
  const _InfiniteRadioHero({required this.seed, required this.onPlay});
  final Song? seed;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(28),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (seed != null && seed!.thumbnail.isNotEmpty)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.32,
                  child: Image.network(seed!.thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      scheme.primary.withValues(alpha: 0.22),
                      scheme.surfaceContainer.withValues(alpha: 0.55),
                      scheme.surfaceContainer,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: scheme.primary.withValues(alpha: 0.16),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.auto_awesome, size: 12, color: scheme.primary),
                      const SizedBox(width: 5),
                      Text('MADE FOR YOU',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: scheme.primary,
                          )),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Text('Infinite Radio',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: scheme.onSurface,
                      )),
                  const SizedBox(height: 4),
                  Text('An endless station shaped by your listening',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: onPlay,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: scheme.primary,
                      ),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded,
                                size: 22, color: scheme.onPrimary),
                            const SizedBox(width: 8),
                            Text('Play',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onPrimary,
                                )),
                          ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The old HomeTab header avatar treatment: card fill, brass ring,
/// honey icon. Pure visual.
class _RingedCircle extends StatelessWidget {
  const _RingedCircle({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: SpotifyColors.surfaceLight,
        shape: BoxShape.circle,
        border: Border.all(color: SpotifyColors.green),
      ),
      child: Icon(icon, size: 20, color: SpotifyColors.highlight),
    );
  }
}