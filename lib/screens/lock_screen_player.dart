import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/song.dart';
import '../services/lock_screen_service.dart';
import '../theme/spotify_theme.dart';
import '../widgets/art_tint.dart';

/// Full-screen player shown over the keyguard. Back is disabled; the
/// only way out is "swipe up to unlock", which goes through the
/// system's PIN / biometric prompt.
class LockScreenPlayer extends StatefulWidget {
  const LockScreenPlayer({super.key});

  @override
  State<LockScreenPlayer> createState() => _LockScreenPlayerState();
}

class _LockScreenPlayerState extends State<LockScreenPlayer> {
  late Timer _clock;
  DateTime _now = DateTime.now();
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  void _unlock() {
    HapticFeedback.mediumImpact();
    LockScreenService.instance.unlock();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: StreamBuilder<Song?>(
          stream: audioHandler.currentSongStream,
          initialData: audioHandler.currentSong,
          builder: (context, snap) {
            final song = snap.data;
            final art = song?.thumbnail ?? '';
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (d) =>
                  setState(() => _drag = (_drag - d.delta.dy).clamp(0.0, 400.0)),
              onVerticalDragEnd: (d) {
                final fast = (d.primaryVelocity ?? 0) < -600;
                if (_drag > 140 || fast) _unlock();
                setState(() => _drag = 0);
              },
              child: Transform.translate(
                offset: Offset(0, -_drag * 0.35),
                child: Opacity(
                  opacity: (1 - _drag / 500).clamp(0.3, 1.0),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _Backdrop(imageUrl: art),
                      SafeArea(child: _content(song)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _content(Song? song) {
    final time = DateFormat('HH:mm').format(_now);
    final date = DateFormat('EEEE, d MMMM').format(_now);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 36),
          Text(time,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 76,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -2)),
          Text(date,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const Spacer(),
          if (song != null) ...[
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: song.thumbnail.isEmpty
                    ? Container(color: Colors.white10)
                    : CachedNetworkImage(
                        imageUrl: song.thumbnail,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: Colors.white10),
                      ),
              ),
            ),
            const SizedBox(height: 22),
            Text(song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 18),
            _Progress(total: song.duration),
            const SizedBox(height: 8),
            _Controls(song: song),
          ] else
            const Text('Nothing playing',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
          const Spacer(),
          GestureDetector(
            onTap: _unlock,
            child: Column(
              children: [
                const Icon(Icons.keyboard_arrow_up_rounded,
                    color: Colors.white70, size: 30),
                const Text('Swipe up to unlock',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LockScreenService.instance.style,
      builder: (context, style, _) {
        if (style == 'minimal' || imageUrl.isEmpty) {
          return ColoredBox(color: SpotifyColors.background);
        }
        if (style == 'art') {
          return ArtTintedBox(
            imageUrl: imageUrl,
            fallback: SpotifyColors.surface,
            gradientToward: Colors.black,
            child: const SizedBox.expand(),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ],
        );
      },
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.total});
  final Duration total;

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: audioHandler.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final t = total.inMilliseconds;
        final v = t <= 0 ? 0.0 : (pos.inMilliseconds / t).clamp(0.0, 1.0);
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: v,
                onChanged: t <= 0
                    ? null
                    : (x) => audioHandler
                        .seek(Duration(milliseconds: (x * t).round())),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(pos),
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12)),
                Text(t <= 0 ? '--:--' : _fmt(total),
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.song});
  final Song song;

  @override
  Widget build(BuildContext context) {
    final liked = storage.getLikedSongs().any((s) => s.id == song.id);
    return StreamBuilder<bool>(
      stream: audioHandler.playingStream,
      initialData: audioHandler.playbackState.value.playing,
      builder: (context, snap) {
        final playing = snap.data ?? false;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _LikeButton(song: song, initial: liked),
            IconButton(
              iconSize: 44,
              color: Colors.white,
              onPressed: audioHandler.skipToPrevious,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                playing ? audioHandler.pause() : audioHandler.play();
              },
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 44),
              ),
            ),
            IconButton(
              iconSize: 44,
              color: Colors.white,
              onPressed: audioHandler.skipToNext,
              icon: const Icon(Icons.skip_next_rounded),
            ),
            const SizedBox(width: 48),
          ],
        );
      },
    );
  }
}

class _LikeButton extends StatefulWidget {
  const _LikeButton({required this.song, required this.initial});
  final Song song;
  final bool initial;

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> {
  late bool _liked = widget.initial;

  @override
  void didUpdateWidget(covariant _LikeButton old) {
    super.didUpdateWidget(old);
    if (old.song.id != widget.song.id) _liked = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 28,
      onPressed: () async {
        setState(() => _liked = !_liked);
        await storage.setLiked(widget.song, _liked);
      },
      icon: Icon(
        _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: _liked ? SpotifyColors.highlight : Colors.white70,
      ),
    );
  }
}
