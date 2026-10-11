import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/physics.dart';
import 'package:flutter/material.dart';
import 'lw_motion.dart';
import 'lw_squircle.dart';

class LwGlass {
  LwGlass._();
  static bool enabled = true;
  /// Set once from device info (RAM gate) — Compose gates on API 31 +
  /// !isLowRamDevice; the dandelion (Android 11, 4GB) is borderline, so
  /// the Settings toggle decides until the RAM check is wired.
  static bool deviceCapable = true;
  static bool get active => enabled && deviceCapable;

  /// Static shim used by LwNavDock: interactive glass when active,
  /// solid elevated Material card as the fallback (LastWave's
  /// LocalLiquidGlass-off path).
  static Widget surface({
    required Widget child,
    BorderRadius radius = const BorderRadius.all(Radius.circular(32)),
    Color fallbackColor = const Color(0xFF201C15),
    EdgeInsets padding = EdgeInsets.zero,
  }) =>
      active
          ? LwGlassSurface(
        radius: radius.topLeft.x,
        padding: padding,
        fallbackColor: fallbackColor,
        pressedScale: 1.04,
        child: child,
      )
          : Material(
        color: fallbackColor,
        shape: RoundedRectangleBorder(borderRadius: radius),
        elevation: 12,
        shadowColor: Colors.black54,
        child: Padding(padding: padding, child: child),
      );
}

class LwGlassSurface extends StatefulWidget {
  const LwGlassSurface({
    super.key,
    required this.child,
    this.radius = 32,
    this.squircle = false,
    this.padding = EdgeInsets.zero,
    this.fallbackColor = const Color(0xFF201C15),
    this.interactive = true,
    this.pressedScale = 1.12,
    this.minScrim = 0.12,
    this.maxScrim = 0.5,
    this.darkTheme = true,
  });

  final Widget child;
  final double radius;
  final bool squircle;
  final EdgeInsets padding;
  final Color fallbackColor;
  final bool interactive;

  /// Compose: pressedScale 1.12 (nav/FAB), 1.04 (mini player).
  final double pressedScale;
  final double minScrim;
  final double maxScrim;
  final bool darkTheme;

  @override
  State<LwGlassSurface> createState() => _LwGlassSurfaceState();
}

class _LwGlassSurfaceState extends State<LwGlassSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press =
  AnimationController(vsync: this, value: 0);
  Offset _touch = Offset.zero;
  final double _luminance = 0.5; // fixed mid — luminance sampling is P6

  void _pressTo(double target) {
    if (!widget.interactive) return;
    _press.animateWith(SpringSimulation(
      LwMotion.spring(0.5, 300), _press.value, target, 0,
    ));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.radius);
    final shape = widget.squircle
        ? LwSquircleBorder(radius: widget.radius)
        : RoundedRectangleBorder(borderRadius: radius) as ShapeBorder;

    // Scrim: lerp(min, max, (lum-0.3)/0.5) — at fixed lum 0.5 → ~0.272.
    final scrimT = (( _luminance - 0.3) / 0.5).clamp(0.0, 1.0);
    final scrimAlpha =
        widget.minScrim + (widget.maxScrim - widget.minScrim) * scrimT;
    final scrimColor = (widget.darkTheme ? Colors.black : Colors.white)
        .withValues(alpha: scrimAlpha);

    Widget content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: DecoratedBox(
          decoration: ShapeDecoration(shape: shape, color: scrimColor),
          child: widget.child,
        ),
      ),
    );

    if (widget.interactive) {
      content = AnimatedBuilder(
        animation: _press,
        builder: (context, child) {
          final p = _press.value;
          final scale = 1 + (widget.pressedScale - 1) * p;
          return MouseRegion(
            onHover: (e) => _touch = e.localPosition,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) {
                _touch = e.localPosition;
                _pressTo(1);
              },
              onPointerUp: (_) => _pressTo(0),
              onPointerCancel: (_) => _pressTo(0),
              onPointerMove: (e) => _touch = e.localPosition,
              child: Transform.scale(
                scale: scale,
                child: CustomPaint(
                  foregroundPainter: p > 0.01
                      ? _PressGlowPainter(
                      progress: p, position: _touch)
                      : null,
                  child: child,
                ),
              ),
            ),
          );
        },
        child: content,
      );
    }
    return content;
  }
}

class _PressGlowPainter extends CustomPainter {
  _PressGlowPainter({required this.progress, required this.position});
  final double progress;
  final Offset position;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        position,
        math.min(size.width, size.height) * 1.2,
        [
          Colors.white.withValues(alpha: 0.18 * progress),
          Colors.white.withValues(alpha: 0),
        ],
      );
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_PressGlowPainter old) =>
      old.progress != progress || old.position != position;
}