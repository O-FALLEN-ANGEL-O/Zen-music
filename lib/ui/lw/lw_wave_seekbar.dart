import 'dart:math' as math;
import 'dart:ui' as ui show Gradient;
import 'package:flutter/material.dart';

/// WavySeekBar port — constants from WavySeekBar.kt (GPL-3.0).
/// 3 counter-gradient glass waves over the active region, tonal-shifted
/// colors, luminous-on-dark tier, glow thumb. Gesture contract: nullable
/// drag fraction, no-value commit = no seek.
class LwWaveSeekBar extends StatefulWidget {
  const LwWaveSeekBar({
    super.key,
    required this.positionMs,
    required this.durationMs,
    required this.isPlaying,
    required this.onSeek,
    this.trackKey,
    this.showTimeLabels = true,
    this.primaryColor,
    this.secondaryColor,
    this.tertiaryColor,
  });

  final int positionMs;
  final int durationMs;
  final bool isPlaying;
  final ValueChanged<int> onSeek;
  final String? trackKey;
  final bool showTimeLabels;
  final Color? primaryColor;
  final Color? secondaryColor;
  final Color? tertiaryColor;

  @override
  State<LwWaveSeekBar> createState() => _LwWaveSeekBarState();
}

class _LwWaveSeekBarState extends State<LwWaveSeekBar>
    with TickerProviderStateMixin {
  bool _isInteracting = false;
  double? _dragMs;
  double? _lastSeekValue;

  late final AnimationController _phase1 = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));
  late final AnimationController _phase2 = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
  late final AnimationController _phase3 = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void initState() {
    super.initState();
    for (final c in [_phase1, _phase2, _phase3]) {
      c.repeat();
    }
  }

  @override
  void dispose() {
    for (final c in [_phase1, _phase2, _phase3]) {
      c.dispose();
    }
    super.dispose();
  }

  int get boundedDuration => widget.durationMs > 0 ? widget.durationMs : 0;

  // ── Tonal helpers (shiftTonal / ensureLuminousForDarkBackground) ──

  static ({double h, double s, double v}) _toHsv(Color c) {
    final r = c.red / 255, g = c.green / 255, b = c.blue / 255;
    final max = math.max(r, math.max(g, b));
    final min = math.min(r, math.min(g, b));
    final d = max - min;
    double h = 0;
    if (d != 0) {
      if (max == r) {
        h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
      } else if (max == g) {
        h = ((b - r) / d + 2) / 6;
      } else {
        h = ((r - g) / d + 4) / 6;
      }
    }
    final s = max == 0 ? 0.0 : d / max;
    return (h: h * 360, s: s, v: max);
  }

  static Color _fromHsv(double h, double s, double v) {
    final hh = (((h % 360) + 360) % 360) / 60;
    final i = hh.floor() % 6;
    final f = hh - hh.floor();
    final c = v * s;
    final x = c * (1 - (f % 2 - 1).abs());
    double r = 0, g = 0, b = 0;
    switch (i) {
      case 0: r = c; g = x; break;
      case 1: r = x; g = c; break;
      case 2: g = c; b = x; break;
      case 3: g = x; b = c; break;
      case 4: r = x; b = c; break;
      case 5: r = c; b = x; break;
    }
    final m = v - c;
    return Color.fromARGB(255, ((r + m) * 255).round(),
        ((g + m) * 255).round(), ((b + m) * 255).round());
  }

  static Color _shiftTonal(Color c,
      {required double lightnessDelta, double saturationScale = 1.0}) {
    final hsv = _toHsv(c);
    final originalS = hsv.s;
    final s =
    (hsv.s * saturationScale).clamp(originalS > 0.05 ? 0.15 : 0.0, 1.0);
    final v = (hsv.v + lightnessDelta)
        .clamp(originalS > 0.05 ? 0.15 : 0.0, 1.0);
    return _fromHsv(hsv.h, s, v);
  }

  static Color _ensureLuminous(Color c, {double minBrightness = 0.55}) {
    final hsv = _toHsv(c);
    var v = hsv.v;
    var s = hsv.s;
    if (v < minBrightness) v = minBrightness;
    if (s > 0.05 && s < 0.35) s = 0.35;
    return _fromHsv(hsv.h, s, v);
  }

  double _smootherstep(double t) {
    final c = t.clamp(0.0, 1.0);
    return c * c * c * (c * (c * 6 - 15) + 10);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = widget.primaryColor ?? scheme.primary;
    final secondary = widget.secondaryColor ?? scheme.secondary;
    final tertiary = widget.tertiaryColor ?? scheme.tertiary;
    // Player context: always on a dark scrim → luminous tier always.
    final effPrimary = _ensureLuminous(primary, minBrightness: 0.60);
    final effSecondary = _ensureLuminous(secondary, minBrightness: 0.52);
    final effTertiary = _ensureLuminous(tertiary, minBrightness: 0.48);

    final layer1Light =
    _shiftTonal(effTertiary, lightnessDelta: 0.18, saturationScale: 0.85);
    final layer1Dark =
    _shiftTonal(effTertiary, lightnessDelta: -0.15, saturationScale: 1.30);
    final layer2Dark =
    _shiftTonal(effSecondary, lightnessDelta: -0.16, saturationScale: 1.30);
    final layer2Light =
    _shiftTonal(effSecondary, lightnessDelta: 0.18, saturationScale: 0.85);
    final layer3Light =
    _shiftTonal(effPrimary, lightnessDelta: 0.20, saturationScale: 0.90);
    final layer3Dark =
    _shiftTonal(effPrimary, lightnessDelta: -0.14, saturationScale: 1.35);
    final thumbColor =
    _shiftTonal(effPrimary, lightnessDelta: -0.06, saturationScale: 1.15);

    final inactive = Colors.white.withValues(alpha: 0.22);
    final textColor = Colors.white.withValues(alpha: 0.85);

    final bounded = boundedDuration;
    final shownMs = bounded > 0
        ? (_dragMs ?? widget.positionMs.clamp(0, bounded))
        : (_dragMs ?? math.max(0, widget.positionMs).toDouble());
    final frac = bounded > 0 ? (shownMs / bounded).clamp(0.0, 1.0) : 0.0;
    final dragging = _isInteracting || _dragMs != null;

    // Wave amplitude: 13/10/7.5dp playing, ~1.2dp while dragging.
    final ampScale = dragging ? 1.2 / 13.0 : 1.0;

    return Column(
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          const height = 50.0;
          final pxPerDp = MediaQuery.devicePixelRatioOf(context);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (d) {
              _isInteracting = true;
              if (bounded > 0) {
                final f = (d.localPosition.dx / (width == 0 ? 1 : width))
                    .clamp(0.0, 1.0);
                _dragMs = f * bounded;
                _lastSeekValue = _dragMs;
              }
            },
            onHorizontalDragUpdate: (d) {
              if (bounded <= 0) return;
              final f = (d.localPosition.dx / (width == 0 ? 1 : width))
                  .clamp(0.0, 1.0);
              setState(() {
                _dragMs = f * bounded;
                _lastSeekValue = _dragMs;
              });
            },
            onHorizontalDragEnd: (d) {
              final target = _lastSeekValue?.round() ?? _dragMs?.round();
              setState(() {
                _dragMs = null;
                _lastSeekValue = null;
                _isInteracting = false;
              });
              if (target != null && bounded > 0) {
                widget.onSeek(target.clamp(0, bounded));
              }
            },
            onHorizontalDragCancel: () {
              setState(() {
                _dragMs = null;
                _lastSeekValue = null;
                _isInteracting = false;
              });
            },
            child: SizedBox(
              width: width,
              height: height,
              child: AnimatedBuilder(
                animation: Listenable.merge([_phase1, _phase2, _phase3]),
                builder: (context, _) => CustomPaint(
                  size: Size(width, height),
                  painter: _WavePainter(
                    fraction: frac.toDouble(),
                    phase1: _phase1.value * 2 * math.pi + 2.2,
                    phase2: _phase2.value * 2 * math.pi + 1.2,
                    phase3: _phase3.value * 2 * math.pi,
                    wavesActive: widget.isPlaying && !dragging,
                    ampScale: ampScale,
                    amp1: 13 * pxPerDp,
                    amp2: 10 * pxPerDp,
                    amp3: 7.5 * pxPerDp,
                    wavelength1: 160 * pxPerDp,
                    wavelength2: 125 * pxPerDp,
                    wavelength3: 95 * pxPerDp,
                    trackThickness: 4.5 * pxPerDp,
                    thumbRadius: 7.5 * pxPerDp,
                    transitionLength: 44 * pxPerDp,
                    sampleStep: 1.5 * pxPerDp,
                    layer1Light: layer1Light,
                    layer1Dark: layer1Dark,
                    layer2Dark: layer2Dark,
                    layer2Light: layer2Light,
                    layer3Light: layer3Light,
                    layer3Dark: layer3Dark,
                    thumbColor: thumbColor,
                    inactive: inactive,
                    hasDuration: bounded > 0,
                  ),
                ),
              ),
            ),
          );
        }),
        if (widget.showTimeLabels) ...[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatTime(shownMs.round()),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: textColor)),
                Text(
                  bounded > 0
                      ? '−${_formatTime((bounded - shownMs.round()).clamp(0, bounded))}'
                      : '--:--',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: textColor),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _formatTime(int ms) {
    final total = (ms < 0 ? 0 : ms) ~/ 1000;
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.fraction,
    required this.phase1,
    required this.phase2,
    required this.phase3,
    required this.wavesActive,
    required this.ampScale,
    required this.amp1,
    required this.amp2,
    required this.amp3,
    required this.wavelength1,
    required this.wavelength2,
    required this.wavelength3,
    required this.trackThickness,
    required this.thumbRadius,
    required this.transitionLength,
    required this.sampleStep,
    required this.layer1Light,
    required this.layer1Dark,
    required this.layer2Dark,
    required this.layer2Light,
    required this.layer3Light,
    required this.layer3Dark,
    required this.thumbColor,
    required this.inactive,
    required this.hasDuration,
  });

  final double fraction;
  final double phase1, phase2, phase3;
  final bool wavesActive;
  final double ampScale;
  final double amp1, amp2, amp3;
  final double wavelength1, wavelength2, wavelength3;
  final double trackThickness;
  final double thumbRadius;
  final double transitionLength;
  final double sampleStep;
  final Color layer1Light, layer1Dark, layer2Dark, layer2Light;
  final Color layer3Light, layer3Dark, thumbColor, inactive;
  final bool hasDuration;

  double _smootherstep(double t) {
    final c = t.clamp(0.0, 1.0);
    return c * c * c * (c * (c * 6 - 15) + 10);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerY = h / 2 + 7;
    final thumbX = (fraction * w).clamp(0.0, w);
    final half = trackThickness / 2;
    final bottomY = centerY + half;
    final topBaseline = centerY - half;

    // 1. Inactive capsule.
    final inactivePaint = Paint()
      ..color = inactive
      ..strokeWidth = trackThickness
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, centerY), Offset(w, centerY), inactivePaint);

    if (thumbX > 0) {
      final clipR = RRect.fromRectAndCorners(
        Rect.fromLTRB(-half, 0, thumbX + half, h),
        topLeft: Radius.circular(half),
        bottomLeft: Radius.circular(half),
        topRight: Radius.circular(half),
        bottomRight: Radius.circular(half),
      );
      canvas.save();
      canvas.clipRRect(clipR);

      final p1 = _wavePath(thumbX, topBaseline, bottomY, wavelength1, amp1,
          wavesActive ? phase1 : 2.2);
      final p2 = _wavePath(thumbX, topBaseline, bottomY, wavelength2, amp2,
          wavesActive ? phase2 : 1.2);
      final p3 = _wavePath(thumbX, topBaseline, bottomY, wavelength3, amp3,
          wavesActive ? phase3 : 0);
      final activeW = thumbX < 1 ? 1.0 : thumbX;

      void contour(Path path, Color a, Color b, double widthDp,
          double alphaA, double alphaB) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = widthDp
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..shader = ui.Gradient.linear(
              Offset(0, 0),
              Offset(activeW, 0),
              [
                a.withValues(alpha: alphaA),
                b.withValues(alpha: alphaB),
              ],
            ),
        );
      }

      contour(p1.contour, layer1Light, layer1Dark, 1.0, 0.42, 0.32);
      contour(p2.contour, layer2Dark, layer2Light, 1.2, 0.72, 0.62);
      contour(p3.contour, layer3Light, layer3Dark, 1.6, 0.98, 0.92);

      canvas.drawLine(
        Offset(0, centerY),
        Offset(thumbX, centerY),
        Paint()
          ..strokeWidth = trackThickness
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(
            Offset(0, 0),
            Offset(activeW, 0),
            [layer3Light, layer3Dark],
          ),
      );
      canvas.restore();
    }

    if (hasDuration) {
      canvas.drawCircle(Offset(thumbX, centerY), thumbRadius + 3,
          Paint()..color = thumbColor.withValues(alpha: 0.28));
      canvas.drawCircle(
          Offset(thumbX, centerY), thumbRadius, Paint()..color = thumbColor);
    }
  }

  ({Path filled, Path contour}) _wavePath(double thumbX, double topBaseline,
      double bottomY, double wavelength, double amp, double phase) {
    final filled = Path()..moveTo(0, bottomY);
    final contour = Path()..moveTo(0, topBaseline);
    filled.lineTo(0, topBaseline);
    contour.lineTo(0, topBaseline);

    final invT = transitionLength > 0 ? 1.0 / transitionLength : 0.0;
    final invWl = 2 * math.pi / wavelength;

    var x = 0.0;
    while (x < thumbX) {
      final startEnv = invT > 0 ? _smootherstep(x * invT) : 1.0;
      final endEnv = invT > 0 ? _smootherstep((thumbX - x) * invT) : 1.0;
      final env = startEnv * endEnv;
      final angle = x * invWl - phase;
      final waveH = (0.5 + 0.5 * math.sin(angle)) * amp * ampScale * env;
      final y = topBaseline - waveH;
      filled.lineTo(x, y);
      contour.lineTo(x, y);
      x += sampleStep;
    }
    filled.lineTo(thumbX, topBaseline);
    contour.lineTo(thumbX, topBaseline);
    filled.lineTo(thumbX, bottomY);
    filled.close();
    return (filled: filled, contour: contour);
  }

  @override
  bool shouldRepaint(_WavePainter old) => true;
}