import 'dart:collection';
import 'package:flutter/material.dart';
import '../../services/artwork_service.dart';

/// ArtworkImage port, mapped to ZenMusic's real artwork service:
///  - embedded thumbnail → ArtworkService.squareArt() upgrade
///    (square w1200-h1200 / maxresdefault, probed ladder, cached),
///  - fallback icon while resolving / when nothing answers.
/// LastWave's metadata-based high-res tier has no ZenMusic equivalent
/// service and is deliberately not faked.
class LwArtwork extends StatefulWidget {
  const LwArtwork({
    super.key,
    required this.songId,
    required this.artworkUrl,
    required this.fallbackIcon,
    this.size = 52,
    this.radius = 14,
    this.circle = false,
  });

  final String songId;
  final String artworkUrl;
  final IconData fallbackIcon;
  final double size;
  final double radius;
  final bool circle;

  @override
  State<LwArtwork> createState() => _LwArtworkState();
}

class _LwArtworkState extends State<LwArtwork> {
  String? _resolvedUrl;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant LwArtwork old) {
    super.didUpdateWidget(old);
    if (old.songId != widget.songId ||
        old.artworkUrl != widget.artworkUrl) {
      _resolvedUrl = null;
      _failed = false;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    if (widget.artworkUrl.isEmpty || widget.songId.isEmpty) return;
    final url = await LwArtworkBus.instance
        .squareArt(widget.artworkUrl, widget.songId);
    if (!mounted) return;
    setState(() => _resolvedUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final display =
    (_failed || _resolvedUrl == null || _resolvedUrl!.isEmpty)
        ? (widget.artworkUrl.isNotEmpty && _resolvedUrl == null
        ? widget.artworkUrl // show raw thumb while probing
        : null)
        : _resolvedUrl!;

    Widget content;
    if (display != null) {
      content = Image.network(
        display,
        fit: BoxFit.cover,
        width: widget.size,
        height: widget.size,
        frameBuilder: (context, child, frame, wasSync) => wasSync
            ? child
            : AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          child: child,
        ),
        errorBuilder: (_, __, ___) {
          if (!_failed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _failed = true);
            });
          }
          return _fallback(scheme);
        },
      );
    } else {
      content = _fallback(scheme);
    }

    final shape = widget.circle
        ? const CircleBorder()
        : RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(widget.radius));
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: ShapeDecoration(
        shape: shape,
        color: scheme.surfaceContainerHighest,
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  Widget _fallback(ColorScheme scheme) => Center(
    child: Icon(
      widget.fallbackIcon,
      size: widget.size * 0.42,
      color: scheme.onSurfaceVariant.withValues(
          alpha: _resolvedUrl == null ? 0.35 : 0.6),
    ),
  );
}

/// Thin process-wide bus over ArtworkService: dedupes in-flight probes
/// (the same song appears in multiple feed shelves at once — one HEAD
/// ladder per song, not one per card) with an LRU of results. The
/// service itself already caches per key; this layer stops concurrent
/// duplicate network work.
class LwArtworkBus {
  LwArtworkBus._();
  static final LwArtworkBus instance = LwArtworkBus._();

  static const int _maxEntries = 512;
  final Map<String, String> _done = LinkedHashMap();
  final Map<String, Future<String>> _inFlight = {};

  Future<String> squareArt(String rawUrl, String songId) {
    final key = '$rawUrl|$songId';
    final done = _done[key];
    if (done != null) return Future.value(done);
    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;
    final future = ArtworkService.instance
        .squareArt(rawUrl, songId)
        .then((url) {
      _done[key] = url;
      if (_done.length > _maxEntries) _done.remove(_done.keys.first);
      return url;
    });
    _inFlight[key] = future;
    future.whenComplete(() => _inFlight.remove(key));
    return future;
  }
}