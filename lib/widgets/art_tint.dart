import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Dark, readable tint sampled from album art — the colour Spotify-style
/// mini players and headers sit on. Results are cached per URL.
class ArtTint {
  ArtTint._();

  static final Map<String, Color> _cache = {};
  static final Map<String, Future<Color?>> _inflight = {};

  static Color? cached(String url) => _cache[url];

  static Future<Color?> of(String url) {
    if (url.isEmpty) return Future.value(null);
    final hit = _cache[url];
    if (hit != null) return Future.value(hit);
    return _inflight.putIfAbsent(url, () async {
      try {
        final p = await PaletteGenerator.fromImageProvider(
          NetworkImage(url),
          size: const Size(64, 64),
          maximumColorCount: 10,
        );
        final base = p.darkVibrantColor?.color ??
            p.vibrantColor?.color ??
            p.darkMutedColor?.color ??
            p.dominantColor?.color;
        if (base == null) return null;
        // Clamp lightness so white text always reads on top.
        final hsl = HSLColor.fromColor(base);
        final c = hsl
            .withLightness(hsl.lightness.clamp(0.18, 0.30))
            .withSaturation(hsl.saturation.clamp(0.25, 0.75))
            .toColor();
        if (_cache.length > 200) _cache.remove(_cache.keys.first);
        _cache[url] = c;
        return c;
      } catch (_) {
        return null;
      } finally {
        _inflight.remove(url);
      }
    });
  }
}

/// A box whose background animates to the artwork tint of [imageUrl].
class ArtTintedBox extends StatefulWidget {
  const ArtTintedBox({
    super.key,
    required this.imageUrl,
    required this.fallback,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.height,
    this.gradientToward,
  });

  final String imageUrl;
  final Color fallback;
  final Widget child;
  final BorderRadius borderRadius;
  final double? height;

  /// When set, paints a vertical gradient from the tint to this colour
  /// (used for page headers) instead of a flat fill.
  final Color? gradientToward;

  @override
  State<ArtTintedBox> createState() => _ArtTintedBoxState();
}

class _ArtTintedBoxState extends State<ArtTintedBox> {
  Color? _tint;
  String? _for;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ArtTintedBox old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl) _resolve();
  }

  void _resolve() {
    final url = widget.imageUrl;
    _for = url;
    final hit = ArtTint.cached(url);
    if (hit != null) {
      _tint = hit;
      return;
    }
    ArtTint.of(url).then((c) {
      if (!mounted || _for != url) return;
      setState(() => _tint = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _tint ?? widget.fallback;
    final toward = widget.gradientToward;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      height: widget.height,
      decoration: BoxDecoration(
        color: toward == null ? c : null,
        gradient: toward == null
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c, toward],
              ),
        borderRadius: widget.borderRadius,
      ),
      child: widget.child,
    );
  }
}
