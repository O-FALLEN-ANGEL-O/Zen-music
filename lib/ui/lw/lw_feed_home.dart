import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../../models/song.dart';
import '../../services/home_service.dart';
import '../../services/storage_service.dart';
import '../../theme/spotify_theme.dart';
import '../../widgets/spotify_home_header.dart';
import '../../widgets/wave_spinner.dart';
import 'lw_feed_section.dart';

/// FeedScreen port with YouTube-Music-style infinite feed:
///  - Pulsing skeleton while the first load runs.
///  - Fresh trending at top on every load/refresh (hero seeds from the
///    latest fetched hits).
///  - Endless "More for you" chart shelves appended on scroll
///    (deduped, end-after-2-empty-fetches), like the old HomeTab.
class LwFeedHome extends StatefulWidget {
  const LwFeedHome(
      {super.key, required this.onOpenSearch, required this.onOpenSettings});
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenSettings;

  @override
  State<LwFeedHome> createState() => _LwFeedHomeState();
}

class _LwFeedHomeState extends State<LwFeedHome>
    with SingleTickerProviderStateMixin {
  final _homeService = HomeService();
  final _scroll = ScrollController();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 0.45,
  );

  List<Song> _biggestHits = [];
  List<Song> _trendingNow = [];
  List<Song> _ytmHot = [];
  List<Song> _ytmFresh = [];
  List<Song> _topCharts = [];
  List<Song> _recent = [];
  bool _loading = true;

  // ── Infinite append state (old HomeTab contract) ──
  final List<({String title, List<Song> songs})> _chartShelves = [];
  final Set<String> _shownSongIds = {};
  bool _loadingMore = false;
  bool _endReached = false;
  int _failedFetches = 0;

  static const _chartTitles = [
    'Chart mix',
    'Throwback chart',
    'Mood chart',
    'Regional chart',
    'Fresh picks',
    'On repeat',
    'Discover',
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _pulse.repeat(reverse: true);
    _loadAll(useCache: true);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _homeService.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _loadingMore || _endReached) return;
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 800) _loadMore();
  }

  String _chartTitle(int index) =>
      _chartTitles[index % _chartTitles.length];

  // ── Instant start: last feed is cached on disk and shown at once,
  // then replaced by fresh data when the network answers. ──
  static const _cacheKey = 'home_feed_cache_v1';

  Future<bool> _loadFromCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_cacheKey);
      if (raw == null) return false;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      List<Song> read(String k) => [
            for (final e in (m[k] as List? ?? const []))
              Song.fromJson(Map<String, dynamic>.from(e as Map)),
          ];
      final hits = read('hits');
      if (hits.isEmpty && read('trending').isEmpty) return false;
      if (!mounted) return false;
      setState(() {
        _biggestHits = hits;
        _trendingNow = read('trending');
        _ytmHot = read('hot');
        _ytmFresh = read('fresh');
        _topCharts = read('charts');
        _recent = storage.getPlayedHistory().take(12).toList();
        _loading = false;
      });
      _pulse.stop();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> enc(List<Song> l) =>
          l.take(20).map((s) => s.toJson()).toList();
      await p.setString(
          _cacheKey,
          jsonEncode({
            'hits': enc(_biggestHits),
            'trending': enc(_trendingNow),
            'hot': enc(_ytmHot),
            'fresh': enc(_ytmFresh),
            'charts': enc(_topCharts),
          }));
    } catch (_) {}
  }

  Future<void> _loadAll({bool useCache = false}) async {
    final fromCache = useCache && await _loadFromCache();
    if (!fromCache) {
      setState(() {
        _loading = true;
        _endReached = false;
        _loadingMore = false;
      });
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    }
    // Each shelf is fetched in parallel and is allowed to fail alone.
    Future<List<Song>> safe(Future<List<Song>> f) =>
        f.timeout(const Duration(seconds: 20)).catchError((_) => <Song>[]);
    final results = await Future.wait([
      safe(_homeService.getBiggestHits()),
      safe(_homeService.getTrendingNow()),
      safe(_homeService.getYtmShelf('top hits this week')),
      safe(_homeService.getYtmShelf('new music this week', limit: 12)),
      safe(_homeService.getTopCharts()),
    ]);
    if (!mounted) return;
    // Keep the cached shelves if the network came back empty (offline).
    final anyFresh = results.any((l) => l.isNotEmpty);
    setState(() {
      if (anyFresh || !fromCache) {
        _biggestHits = results[0];
        _trendingNow = results[1];
        _ytmHot = results[2];
        _ytmFresh = results[3];
        _topCharts = results[4];
      }
      _recent = storage.getPlayedHistory().take(12).toList();
      _loading = false;
      _endReached = false;
      _loadingMore = false;
      // Dedupe seed: everything already on screen never re-appears in
      // an appended shelf.
      _shownSongIds
        ..clear()
        ..addAll(_biggestHits.map((s) => s.id))
        ..addAll(_trendingNow.map((s) => s.id))
        ..addAll(_ytmHot.map((s) => s.id))
        ..addAll(_ytmFresh.map((s) => s.id))
        ..addAll(_topCharts.map((s) => s.id));
      _chartShelves.clear();
    });
    _pulse.stop();
    if (anyFresh) unawaited(_saveCache());
  }

  /// Appends the next chart shelf while scrolling. Stops after the
  /// rotation pool fails to add genuinely-new content twice in a row.
  Future<void> _loadMore() async {
    if (_loadingMore || _endReached) return;
    setState(() => _loadingMore = true);
    try {
      final songs = await _homeService.getNextChartShelf();
      if (!mounted) return;
      final fresh = songs.where((s) => _shownSongIds.add(s.id)).toList();
      if (fresh.length < 5) {
        _failedFetches++;
        if (_failedFetches >= 2) {
          setState(() {
            _endReached = true;
            _loadingMore = false;
          });
          return;
        }
        setState(() => _loadingMore = false);
        unawaited(_loadMore());
        return;
      }
      _failedFetches = 0;
      setState(() {
        _chartShelves.add((
        title: 'More for you · ${_chartTitle(_chartShelves.length)}',
        songs: fresh,
        ));
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      _failedFetches++;
      if (_failedFetches >= 3) {
        setState(() {
          _endReached = true;
          _loadingMore = false;
        });
      } else {
        setState(() => _loadingMore = false);
      }
    }
  }

  void _playQueue(List<Song> songs, int index) {
    if (songs.isEmpty) return;
    audioHandler.setQueue(songs, startIndex: index);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: _loading
          ? _FeedSkeleton(pulse: _pulse)
          : ListView(
        controller: _scroll,
        padding: const EdgeInsets.only(top: 12, bottom: 190),
        children: [
          // Spotify-style header: greeting, chips, quick picks.
          SpotifyHomeHeader(
            recent: _recent,
            onOpenSettings: widget.onOpenSettings,
          ),
          const SizedBox(height: 22),
          _InfiniteRadioHero(
            seed: _biggestHits.isNotEmpty
                ? _biggestHits.first
                : (_trendingNow.isNotEmpty
                ? _trendingNow.first
                : null),
            onPlay: () {
              final seed = _biggestHits.isNotEmpty
                  ? _biggestHits.first
                  : _trendingNow.firstOrNull;
              if (seed != null) audioHandler.startRadio(seed);
            },
          ),
          const SizedBox(height: 24),
          if (_recent.isNotEmpty) ...[
            LwFeedSectionHeader(
                title: 'Jump back in',
                subtitle: 'From your listening history',
                actionText: 'Play all',
                actionIcon: Icons.play_arrow_rounded,
                onAction: () => _playQueue(_recent, 0)),
            const SizedBox(height: 12),
            _shelf(_recent, (i) => _playQueue(_recent, i)),
          ],
          const SizedBox(height: 24),
          // Free & legal catalogue picks (Audius / Archive / Jamendo).
          const FreeMusicShelf(),
          if (_biggestHits.isNotEmpty) ...[
            LwSectionCard(
              child: Column(children: [
                LwFeedSectionHeader(
                    title: 'Popular right now',
                    subtitle: 'Most popular right now · up to date',
                    actionText: 'Play all',
                    actionIcon: Icons.play_arrow_rounded,
                    onAction: () => _playQueue(_biggestHits, 0),
                    onShuffle: () => _playQueue(
                        List<Song>.from(_biggestHits)..shuffle(), 0)),
                const SizedBox(height: 12),
                _shelf(_biggestHits,
                        (i) => _playQueue(_biggestHits, i)),
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
                _shelf(_ytmHot, (i) => _playQueue(_ytmHot, i)),
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
                _shelf(_topCharts, (i) => _playQueue(_topCharts, i)),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          if (_ytmFresh.isNotEmpty) ...[
            LwSectionCard(
              child: Column(children: [
                LwFeedSectionHeader(
                    title: 'Fresh finds',
                    subtitle:
                    'New tracks beyond your usual rotation',
                    actionText: 'Play all',
                    actionIcon: Icons.play_arrow_rounded,
                    onAction: () => _playQueue(_ytmFresh, 0)),
                const SizedBox(height: 12),
                _shelf(_ytmFresh, (i) => _playQueue(_ytmFresh, i),
                    badge: 'NEW'),
              ]),
            ),
          ],
          const SizedBox(height: 24),

          // ── Infinite chart shelves (appended on scroll) ──
          for (final shelf in _chartShelves) ...[
            LwSectionCard(
              child: Column(children: [
                LwFeedSectionHeader(
                    title: shelf.title,
                    actionText: 'Play all',
                    actionIcon: Icons.play_arrow_rounded,
                    onAction: () => _playQueue(shelf.songs, 0),
                    onShuffle: () => _playQueue(
                        List<Song>.from(shelf.songs)..shuffle(), 0)),
                const SizedBox(height: 12),
                _shelf(shelf.songs, (i) => _playQueue(shelf.songs, i)),
              ]),
            ),
            const SizedBox(height: 24),
          ],

          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: WaveSpinner(size: 22)),
            )
          else if (_endReached)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'You\'re all caught up — pull to refresh',
                  style: TextStyle(
                      color: SpotifyColors.textTertiary,
                      fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shelf(List<Song> songs, ValueChanged<int> onTap,
      {String? badge}) {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: songs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => LwMediaCard(
          songId: songs[i].id,
          artworkUrl: songs[i].thumbnail,
          title: songs[i].title,
          subtitle: songs[i].artist,
          badgeText: badge,
          onTap: () => onTap(i),
          onPlay: () => onTap(i),
        ),
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
                      Icon(Icons.auto_awesome,
                          size: 12, color: scheme.primary),
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

/// Pulsing skeleton matching the feed layout: masthead bar, hero block,
/// tile row, three shelf groups (title bar + 148dp squares). LastWave's
/// FeedLoadingSkeleton geometry with the Zen palette.
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton({required this.pulse});
  final Animation<double> pulse;

  Widget _box({double? w, double? h, double r = 18}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: SpotifyColors.surfaceLight
            .withValues(alpha: 0.35 + 0.45 * pulse.value),
        borderRadius: BorderRadius.circular(r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12, bottom: 190),
      children: [
        // Masthead: title bar + two action circles.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
          child: Row(
            children: [
              _box(w: 140, h: 26, r: 8),
              const Spacer(),
              _box(w: 42, h: 42, r: 21),
              const SizedBox(width: 10),
              _box(w: 42, h: 42, r: 21),
            ],
          ),
        ),
        // Hero block.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _box(h: 208, r: 28),
        ),
        const SizedBox(height: 24),
        // Quick tiles row.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (var i = 0; i < 2; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: _box(h: 64, r: 18)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Three shelf groups.
        for (var g = 0; g < 3; g++) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _box(w: 140.0 + g * 30, h: 18, r: 8),
          ),
          SizedBox(
            height: 190,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(w: 148, h: 148),
                      const SizedBox(height: 8),
                      _box(w: 110, h: 12, r: 6),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ],
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