import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../main.dart';
import '../models/song.dart';
import '../services/appearance_prefs.dart';
import '../services/downloads_service.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../theme/spotify_theme.dart';
import '../ui/lw/lw_feed_home.dart';
import '../ui/lw/lw_nav_dock.dart';
import '../utilities/zen_transitions.dart';
import '../widgets/art_tint.dart';
import '../widgets/marquee.dart';
import '../widgets/playlist_sheets.dart';
import '../widgets/spotify_nav_bar.dart';
import '../widgets/wave_spinner.dart';
import '../widgets/welcome_dialog.dart';
import '../widgets/youtube_thumbnail.dart';
import 'equalizer_screen.dart';
import 'history_screen.dart';
import 'import_spotify_screen.dart';
import 'liked_songs_screen.dart';
import 'player_screen.dart';
import 'radio_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'user_playlist_screen.dart';
import 'video_watch_screen.dart';
import 'youtube_tab_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

  // Nav auto-hide: hides on scroll-down, returns on scroll-up or at
  // any list's top (vertical lists only — horizontal shelf swipes
  // are ignored via the axis filter; IDLE keeps the current state).
  bool _navVisible = true;

  @override
  void initState() {
    super.initState();
    AppearancePrefs.load().then((_) {
      if (!mounted) return;
      final tab = AppearancePrefs.defaultTab.value;
      setState(() => _currentTab = tab < 0 ? 0 : (tab > 3 ? 3 : tab));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await WelcomeDialog.maybeShow(context);
      if (!mounted) return;
      await UpdateService.instance.checkOnLaunch(context);
    });
  }

  void _selectTab(int i) {
    if (i == _currentTab) return;
    setState(() => _currentTab = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.background,
      // Floating LastWave-style chrome: mini player above the glass
      // dock, both overlaying content (no Scaffold bottom bar).
      body: Stack(
        children: [
          NotificationListener<UserScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis != Axis.vertical) return false;
              if (n.metrics.pixels <= 0) {
                if (!_navVisible && mounted) setState(() => _navVisible = true);
                return false;
              }
              if (n.direction == ScrollDirection.reverse) {
                if (_navVisible && mounted) setState(() => _navVisible = false);
              } else if (n.direction == ScrollDirection.forward) {
                if (!_navVisible && mounted) setState(() => _navVisible = true);
              }
              return false;
            },
            child: _TabStack(
              index: _currentTab,
              children: [
                LwFeedHome(
                  onOpenSearch: () => _selectTab(1),
                  onOpenSettings: () =>
                      pushSharedAxisY(context, const SettingsScreen()),
                ),
                const SearchScreen(),
                const LibraryTab(),
                const YoutubeTab(),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSlide(
              offset: _navVisible ? Offset.zero : const Offset(0, 1.25),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MiniPlayer(),
                  ValueListenableBuilder<String>(
                    valueListenable: AppearancePrefs.navStyle,
                    builder: (context, style, _) => style == 'dock'
                        ? LwNavDock(
                            tabs: const [
                              LwNavItemSpec(label: 'Home', icon: Icons.home_outlined),
                              LwNavItemSpec(label: 'Search', icon: Icons.search_rounded),
                              LwNavItemSpec(label: 'Library', icon: Icons.library_music_outlined),
                              LwNavItemSpec(label: 'Videos', icon: Icons.play_circle_outline_rounded),
                            ],
                            selectedIndex: _currentTab,
                            onSelect: _selectTab,
                          )
                        : SpotifyNavBar(
                            items: const [
                              SpotifyNavItem(
                                  label: 'Home',
                                  icon: Icons.home_outlined,
                                  selectedIcon: Icons.home_rounded),
                              SpotifyNavItem(
                                  label: 'Search',
                                  icon: Icons.search_rounded,
                                  selectedIcon: Icons.manage_search_rounded),
                              SpotifyNavItem(
                                  label: 'Your Library',
                                  icon: Icons.library_music_outlined,
                                  selectedIcon: Icons.library_music_rounded),
                              SpotifyNavItem(
                                  label: 'Videos',
                                  icon: Icons.play_circle_outline_rounded,
                                  selectedIcon: Icons.play_circle_rounded),
                            ],
                            selectedIndex: _currentTab,
                            onSelect: _selectTab,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════
// SLIDING TAB STACK — state-preserving. Every tab stays mounted
// (scroll positions / data kept); adjacent tabs stay painted during
// the slide; non-active tabs ignore pointers, tickers disabled.
// ═════════════════════════════════════════════

class _TabStack extends StatelessWidget {
  final int index;
  final List<Widget> children;

  const _TabStack({required this.index, required this.children});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          AnimatedSlide(
            offset: Offset((i - index).toDouble().clamp(-1.0, 1.0), 0),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            child: Offstage(
              offstage: (i - index).abs() > 1,
              child: TickerMode(
                enabled: i == index,
                child: IgnorePointer(
                  ignoring: i != index,
                  child: children[i],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ═════════════════════════════════════════════
// MINI PLAYER — structure unchanged; recolors via theme tokens.
// ═════════════════════════════════════════════

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  static const double _playerHeight = 72;
  static const double _borderRadius = 20;
  static const double _artworkSize = 52;
  static const double _artworkRadius = 14;

  PageRoute<void> _createSlideTransition() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, _) => const PlayerScreen(),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: const Offset(0, 1), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeInOut));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  void _openNowPlaying(BuildContext context) {
    // An active video session reopens the WATCH page instead of the
    // audio player, resuming at the LIVE handler position.
    if (VideoSession.active) {
      final sameAudio =
          audioHandler.mediaItem.value?.id == VideoSession.videoId;
      var resume = VideoSession.position;
      if (sameAudio) {
        final ps = audioHandler.playbackState.value;
        final live = ps.position +
            (ps.playing
                ? DateTime.now().difference(ps.updateTime)
                : Duration.zero);
        if (live > Duration.zero) resume = live;
      }
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VideoWatchScreen(
          videoId: VideoSession.videoId,
          title: VideoSession.title,
          artist: VideoSession.artist,
          thumbnail: VideoSession.thumbnail,
          startPosition: resume,
        ),
      ));
      return;
    }
    Navigator.of(context).push(_createSlideTransition());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, mediaSnapshot) {
        final metadata = mediaSnapshot.data;
        if (metadata == null) return const SizedBox.shrink();

        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, stateSnapshot) {
            final state = stateSnapshot.data;
            if (state == null) return const SizedBox.shrink();

            return StreamBuilder<List<MediaItem>>(
              stream: audioHandler.queue,
              builder: (context, queueSnapshot) {
                final queue = queueSnapshot.data ?? const [];
                final hasNext = queue.length > 1 &&
                    (state.queueIndex ?? 0) < queue.length - 1;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: _MiniPlayerBody(
                    metadata: metadata,
                    playbackState: state,
                    hasNext: hasNext,
                    onOpen: () => _openNowPlaying(context),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MiniPlayerBody extends StatefulWidget {
  const _MiniPlayerBody({
    required this.metadata,
    required this.playbackState,
    required this.hasNext,
    required this.onOpen,
  });

  final MediaItem metadata;
  final PlaybackState playbackState;
  final bool hasNext;
  final VoidCallback onOpen;

  @override
  State<_MiniPlayerBody> createState() => _MiniPlayerBodyState();
}

class _MiniPlayerBodyState extends State<_MiniPlayerBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  static const double _dragThreshold = 10;

  // ── Track-change slide state (player-screen parity) ──
  bool _slideForward = true;
  bool? _pendingSlideForward;
  DateTime _slideIntentAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastSlideSongId;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _noteSlideIntent(bool forward) {
    _pendingSlideForward = forward;
    _slideIntentAt = DateTime.now();
  }

  void _consumeSlideIntentIfNeeded() {
    final id = widget.metadata.id;
    if (id == _lastSlideSongId) return;
    final pending = _pendingSlideForward;
    if (pending != null &&
        DateTime.now().difference(_slideIntentAt) <
            const Duration(milliseconds: 3000)) {
      _slideForward = pending;
    }
    _pendingSlideForward = null;
    _lastSlideSongId = id;
  }

  void _handleVerticalDrag(DragUpdateDetails details) {
    if ((details.primaryDelta ?? 0) < -_dragThreshold) {
      widget.onOpen();
    }
  }

  Widget _slideOnChange({
    required String slideKey,
    required Widget child,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.hardEdge,
        children: [
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey<String>(slideKey);
        final Offset slideFrom = incoming
            ? Offset(_slideForward ? 0.35 : -0.35, 0)
            : Offset(_slideForward ? -0.35 : 0.35, 0);
        return IgnorePointer(
          ignoring: !incoming,
          child: FadeTransition(
            opacity: incoming
                ? Tween<double>(begin: 0.35, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut))
                : Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeIn)),
            child: SlideTransition(
              position: Tween<Offset>(begin: slideFrom, end: Offset.zero)
                  .animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<String>(slideKey),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _consumeSlideIntentIfNeeded();
    final metadata = widget.metadata;
    final state = widget.playbackState;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _animationController.forward(),
            onTapUp: (_) => _animationController.reverse(),
            onTapCancel: () => _animationController.reverse(),
            onVerticalDragUpdate: _handleVerticalDrag,
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -300) {
                _noteSlideIntent(true);
                audioHandler.skipToNext();
              } else if (v > 300) {
                _noteSlideIntent(false);
                audioHandler.skipToPrevious();
              }
            },
            onTap: widget.onOpen,
            child: ValueListenableBuilder<String>(
              valueListenable: AppearancePrefs.miniPlayerBackground,
              builder: (context, miniBg, _) {
                final box = Container(
                height: MiniPlayer._playerHeight,
                decoration: BoxDecoration(
                  color: miniBg == 'tint'
                      ? Colors.transparent
                      : SpotifyColors.surface,
                  gradient: miniBg == 'gradient'
                      ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      SpotifyColors.green,
                      SpotifyColors.surface,
                    ],
                  )
                      : null,
                  borderRadius:
                  BorderRadius.circular(MiniPlayer._borderRadius),
                ),
                child: ClipRRect(
                  borderRadius:
                  BorderRadius.circular(MiniPlayer._borderRadius),
                  child: Stack(
                    children: [
                      if (miniBg == 'blur' &&
                          (metadata.artUri?.toString().isNotEmpty ?? false))
                        Positioned.fill(
                          child: CachedNetworkImage(
                            imageUrl: metadata.artUri.toString(),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                            const SizedBox.shrink(),
                          ),
                        ),
                      if (miniBg == 'blur')
                        Positioned.fill(
                          child: BackdropFilter(
                            filter:
                            ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: ColoredBox(
                                color: Colors.black.withOpacity(0.35)),
                          ),
                        ),
                      Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            _slideOnChange(
                              slideKey: metadata.id,
                              child: _Artwork(metadata: metadata),
                            ),
                            Expanded(
                              child: _slideOnChange(
                                slideKey: 'meta-${metadata.id}',
                                child: _Metadata(
                                  title: metadata.title,
                                  artist: metadata.artist ?? '',
                                ),
                              ),
                            ),
                            _Controls(
                              playbackState: state,
                              hasNext: widget.hasNext &&
                                  !audioHandler.isRadioMode,
                              totalDuration:
                              metadata.duration ?? Duration.zero,
                              onNextIntent: () => _noteSlideIntent(true),
                            ),
                          ],
                        ),
                      ),
                      // Spotify-style hairline progress along the bottom.
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 0,
                        child: _MiniProgress(
                            total: metadata.duration ?? Duration.zero),
                      ),
                    ],
                  ),
                ),
              );
                if (miniBg != 'tint') return box;
                return ArtTintedBox(
                  imageUrl: metadata.artUri?.toString() ?? '',
                  fallback: SpotifyColors.surfaceLight,
                  borderRadius:
                      BorderRadius.circular(MiniPlayer._borderRadius),
                  child: box,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress({required this.total});
  final Duration total;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: audioHandler.positionStream,
      builder: (context, snap) {
        final t = total.inMilliseconds;
        if (t <= 0) return const SizedBox.shrink();
        final v = ((snap.data?.inMilliseconds ?? 0) / t).clamp(0.0, 1.0);
        return ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: v,
            minHeight: 2,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            color: Colors.white,
          ),
        );
      },
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.metadata});
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final url = metadata.artUri?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MiniPlayer._artworkRadius),
        child: url.isEmpty
            ? Container(
          width: MiniPlayer._artworkSize,
          height: MiniPlayer._artworkSize,
          color: SpotifyColors.surfaceLight,
          child: Icon(
            Icons.music_note_rounded,
            size: 24,
            color: SpotifyColors.textTertiary,
          ),
        )
            : CachedNetworkImage(
          imageUrl: url,
          width: MiniPlayer._artworkSize,
          height: MiniPlayer._artworkSize,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: MiniPlayer._artworkSize,
            height: MiniPlayer._artworkSize,
            color: SpotifyColors.surfaceLight,
            child: const Center(
              child: WaveSpinner(size: 18, strokeWidth: 2),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            width: MiniPlayer._artworkSize,
            height: MiniPlayer._artworkSize,
            color: SpotifyColors.surfaceLight,
            child: Icon(
              Icons.music_note_rounded,
              size: 24,
              color: SpotifyColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.title, required this.artist});

  final String title;
  final String artist;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarqueeWidget(
            manualScrollEnabled: false,
            animationDuration: const Duration(seconds: 8),
            backDuration: const Duration(seconds: 2),
            pauseDuration: const Duration(seconds: 2),
            child: Text(
              title,
              style: TextStyle(
                color: SpotifyColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (artist.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              artist,
              style: TextStyle(
                color: SpotifyColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.playbackState,
    required this.hasNext,
    required this.totalDuration,
    this.onNextIntent,
  });

  final PlaybackState playbackState;
  final bool hasNext;
  final Duration totalDuration;
  final VoidCallback? onNextIntent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircularPlayButton(
          playbackState: playbackState,
          totalDuration: totalDuration,
        ),
        if (hasNext) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: () {
              onNextIntent?.call();
              audioHandler.skipToNext();
            },
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            icon: Icon(
              FluentIcons.next_24_filled,
              color: SpotifyColors.textSecondary,
              size: 24,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }
}

// ═════════════════════════════════════════════
// CIRCULAR PLAY BUTTON — wavy arc ring only: arc = progress, wave
// travels while playing, flattens when paused.
// ═════════════════════════════════════════════

class _CircularPlayButton extends StatefulWidget {
  const _CircularPlayButton({
    required this.playbackState,
    required this.totalDuration,
  });

  final PlaybackState playbackState;
  final Duration totalDuration;

  @override
  State<_CircularPlayButton> createState() => _CircularPlayButtonState();
}

class _CircularPlayButtonState extends State<_CircularPlayButton>
    with TickerProviderStateMixin {
  late final AnimationController _phase = AnimationController(
    duration: const Duration(milliseconds: 2000),
    vsync: this,
  );
  late final AnimationController _amp = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    value: 0,
  );

  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _playing = widget.playbackState.playing;
    if (_playing) {
      _phase.repeat();
      _amp.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _CircularPlayButton old) {
    super.didUpdateWidget(old);
    final playing = widget.playbackState.playing;
    if (playing != _playing) {
      _playing = playing;
      if (playing) {
        _phase.repeat();
        _amp.forward();
      } else {
        _amp.reverse();
        _phase.stop();
      }
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    _amp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final processingState = widget.playbackState.processingState;
    final isPlaying = widget.playbackState.playing;
    final isLoading = processingState == AudioProcessingState.loading ||
        processingState == AudioProcessingState.buffering;
    final isCompleted = processingState == AudioProcessingState.completed;

    return SizedBox(
      width: 48,
      height: 48,
      // Duration fallback: YTM-resolved songs can carry a zero
      // MediaItem duration — the player's real duration stream fills
      // in, so the wave ring tracks progress for every source.
      child: StreamBuilder<Duration?>(
        stream: audioHandler.durationStream,
        builder: (context, durSnap) {
          final total = widget.totalDuration.inMilliseconds > 0
              ? widget.totalDuration
              : (durSnap.data ?? Duration.zero);
          return StreamBuilder<Duration>(
            stream: audioHandler.positionStream,
            builder: (context, posSnap) {
              final position = posSnap.data ?? Duration.zero;
              final progress = total.inMilliseconds == 0
                  ? 0.0
                  : (position.inMilliseconds / total.inMilliseconds)
                  .clamp(0.0, 1.0);

              return Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([_phase, _amp]),
                    builder: (context, _) => CustomPaint(
                      size: const Size(48, 48),
                      painter: WaveRingPainter(
                        phase: _phase.value * 2 * math.pi,
                        startAngle: -math.pi / 2,
                        sweepAngle:
                        2 * math.pi * progress.clamp(0.0, 1.0),
                        color: SpotifyColors.highlight,
                        strokeWidth: 3,
                        amplitude: 1.6 * _amp.value,
                      ),
                    ),
                  ),
                  if (isLoading)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            SpotifyColors.highlight),
                      ),
                    )
                  else
                    IconButton(
                      onPressed: isCompleted
                          ? () async {
                        await audioHandler.seek(Duration.zero);
                        await audioHandler.play();
                      }
                          : (isPlaying
                          ? audioHandler.pause
                          : audioHandler.play),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      icon: Icon(
                        isCompleted
                            ? FluentIcons
                            .arrow_counterclockwise_24_filled
                            : (isPlaying
                            ? FluentIcons.pause_16_filled
                            : FluentIcons.play_16_filled),
                        color: SpotifyColors.textPrimary,
                        size: 22,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════
// LIBRARY TAB (structure unchanged)
// ═════════════════════════════════════════════

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  List<Song> _played = [];
  List<({String id, String name, int count})> _userPlaylists = [];
  List<Song> _downloads = [];
  bool _loadingDownloads = true;
  int _likedCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _played = storage.getPlayedHistory();
      _userPlaylists = storage.getUserPlaylists();
      _likedCount = storage.getLikedSongs().length;
    });
    DownloadsService().downloadedSongs().then((list) {
      if (!mounted) return;
      setState(() {
        _downloads = list;
        _loadingDownloads = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Your library',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: SpotifyColors.textPrimary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.history_rounded,
                    color: SpotifyColors.textSecondary,
                  ),
                  tooltip: 'History',
                  onPressed: () =>
                      pushSharedAxisY(context, const HistoryScreen()),
                ),
                IconButton(
                  icon: Icon(
                    Icons.radio_rounded,
                    color: SpotifyColors.textSecondary,
                  ),
                  tooltip: 'Radio',
                  onPressed: () =>
                      pushSharedAxisY(context, const RadioScreen()),
                ),
                IconButton(
                  icon: Icon(
                    Icons.tune_rounded,
                    color: SpotifyColors.textSecondary,
                  ),
                  tooltip: 'Equalizer',
                  onPressed: () =>
                      pushSharedAxisY(context, const EqualizerScreen()),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Your playlists',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: SpotifyColors.textPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: SpotifyColors.surface,
                        title: const Text('Delete all downloads?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await DownloadsService().deleteAll();
                      _load();
                    }
                  },
                  icon: Icon(
                    FluentIcons.delete_24_regular,
                    size: 16,
                    color: SpotifyColors.textTertiary,
                  ),
                  label: Text(
                    'Clear downloads',
                    style: TextStyle(
                        fontSize: 12, color: SpotifyColors.textTertiary),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => pushSharedAxisY(
                    context,
                    const ImportSpotifyScreen(),
                  ).then((_) => _load()),
                  icon: Icon(
                    FluentIcons.arrow_upload_24_regular,
                    size: 16,
                    color: SpotifyColors.highlight,
                  ),
                  label: Text(
                    'Import',
                    style:
                    TextStyle(fontSize: 13, color: SpotifyColors.highlight),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => pushSharedAxisY(
                        context, const LikedSongsScreen()),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            SpotifyColors.highlight,
                            SpotifyColors.green,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(FluentIcons.heart_24_filled,
                              color: SpotifyColors.background, size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Liked songs',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: SpotifyColors.background,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final name = await showCreatePlaylistSheet(context);
                    if (name == null) return;
                    await storage.createUserPlaylist(name);
                    _load();
                  },
                  child: Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: SpotifyColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add_rounded,
                        color: SpotifyColors.textPrimary, size: 26),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_userPlaylists.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _userPlaylists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final p = _userPlaylists[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => pushSharedAxisY(
                      context,
                      UserPlaylistScreen(id: p.id, name: p.name),
                    ).then((_) => _load()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: SpotifyColors.surface,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        '${p.name} · ${p.count}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: SpotifyColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (!_loadingDownloads && _downloads.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.download_rounded,
                      size: 16, color: SpotifyColors.highlight),
                  const SizedBox(width: 6),
                  Text(
                    'Downloads · ${_downloads.length}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: SpotifyColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                clipBehavior: Clip.none,
                itemCount: _downloads.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final song = _downloads[i];
                  return GestureDetector(
                    onTap: () async {
                      await audioHandler.setQueue([song], startIndex: 0);
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PlayerScreen()),
                      );
                    },
                    child: SizedBox(
                      width: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          YoutubeThumbnail(
                            videoId: song.id,
                            imageUrl: song.thumbnail,
                            width: 140,
                            height: 140,
                            borderRadius: 10,
                          ),
                          const SizedBox(height: 8),
                          Text(song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: SpotifyColors.textPrimary)),
                          Text(song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: SpotifyColors.textSecondary)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: _played.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_music_rounded,
                    size: 56,
                    color: SpotifyColors.textTertiary.withOpacity(0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nothing here yet',
                    style: TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Songs you play will appear here',
                    style: TextStyle(
                      color:
                      SpotifyColors.textTertiary.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 190),
              itemCount: _played.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final song = _played[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    audioHandler.startRadio(song);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PlayerScreen(),
                      ),
                    ).then((_) => _load());
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        YoutubeThumbnail(
                          videoId: song.id,
                          imageUrl: song.thumbnail,
                          width: 52,
                          height: 52,
                          borderRadius: 6,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: SpotifyColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: SpotifyColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.play_circle_outline_rounded,
                          size: 22,
                          color: SpotifyColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}