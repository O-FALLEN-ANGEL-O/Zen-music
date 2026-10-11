import 'dart:math' as math;
import 'package:flutter/material.dart';

/// SquircleShape port — continuous-curvature superellipse with LastWave's
/// exact control-point constants (k = 1.528665). Used for glass surfaces;
/// the nav dock itself stays a plain 32dp rounded rect per MainShell.
Path lwSquirclePath(Size size, double radius) {
  final w = size.width, h = size.height;
  final path = Path();
  if (w <= 0 || h <= 0) return path;
  final maxRadius = math.min(w, h) / 2;
  final r = radius.clamp(0.0, maxRadius);
  if (r <= 0) {
    path.addRect(Offset.zero & size);
    return path;
  }

  const k = 1.528665;
  final l = r * k;

  path.moveTo(l, 0);
  path.lineTo(w - l, 0);
  if (l > 0.001) {
    path.cubicTo(
        w - l * (1 - 0.712053), 0,
        w - l * (1 - 0.566789), l * 0.030183,
        w - l * (1 - 0.455953), l * 0.087377);
    path.cubicTo(
        w - l * (1 - 0.345118), l * 0.144571,
        w - l * (1 - 0.242846), l * 0.242846,
        w - l * (1 - 0.144571), l * 0.345118);
    path.cubicTo(
        w - l * (1 - 0.087377), l * 0.455953,
        w - l * 0.030183, l * (1 - 0.566789),
        w, l * (1 - 0.712053));
    path.lineTo(w, l);
  } else {
    path.lineTo(w, 0);
  }
  path.lineTo(w, h - l);
  if (l > 0.001) {
    path.cubicTo(
        w, h - l * (1 - 0.712053),
        w - l * 0.030183, h - l * (1 - 0.566789),
        w - l * 0.087377, h - l * (1 - 0.455953));
    path.cubicTo(
        w - l * 0.144571, h - l * (1 - 0.345118),
        w - l * 0.242846, h - l * (1 - 0.242846),
        w - l * 0.345118, h - l * (1 - 0.144571));
    path.cubicTo(
        w - l * 0.455953, h - l * (1 - 0.087377),
        w - l * (1 - 0.566789), h - l * 0.030183,
        w - l * (1 - 0.712053), h);
    path.lineTo(w - l, h);
  } else {
    path.lineTo(w, h);
  }
  path.lineTo(l, h);
  if (l > 0.001) {
    path.cubicTo(
        l * (1 - 0.712053), h,
        l * (1 - 0.566789), h - l * 0.030183,
        l * 0.455953, h - l * 0.087377);
    path.cubicTo(
        l * 0.345118, h - l * 0.144571,
        l * 0.242846, h - l * 0.242846,
        l * 0.144571, h - l * 0.345118);
    path.cubicTo(
        l * 0.087377, h - l * 0.455953,
        l * 0.030183, h - l * (1 - 0.566789),
        0, h - l * (1 - 0.712053));
    path.lineTo(0, h - l);
  } else {
    path.lineTo(0, h);
  }
  path.lineTo(0, l);
  if (l > 0.001) {
    path.cubicTo(
        0, l * (1 - 0.712053),
        l * 0.030183, l * (1 - 0.566789),
        l * 0.087377, l * (1 - 0.455953));
    path.cubicTo(
        l * 0.144571, l * (1 - 0.345118),
        l * 0.242846, l * 0.242846,
        l * 0.345118, l * 0.144571);
    path.cubicTo(
        l * 0.455953, l * (1 - 0.087377),
        l * (1 - 0.566789), l * 0.030183,
        l * (1 - 0.712053), 0);
    path.lineTo(l, 0);
  } else {
    path.lineTo(0, 0);
  }
  path.close();
  return path;
}

class LwSquircleBorder extends ShapeBorder {
  const LwSquircleBorder({this.radius = 24});
  final double radius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      lwSquirclePath(rect.size, radius)..shift(rect.topLeft);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => LwSquircleBorder(radius: radius * t);
}