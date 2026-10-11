import 'package:flutter/material.dart';

/// Md3SchemeBuilder port — exact constants from LastWave (GPL-3.0).
/// Deliberately NOT Flutter's HCT-based ColorScheme.fromSeed: using that
/// would shift every color relationship. This mirrors LastWave's
/// app.js-lineage HSL tonal roles so nothing needs re-approving visually.
class LwScheme {
  LwScheme._();

  // Chroma levels (CSS HSL %) — exact.
  static const int _chromaPrimary = 30;
  static const int _chromaSecondary = 14;
  static const int _chromaTertiary = 22;
  static const int _chromaNeutral = 5;
  static const int _chromaNeutralVariant = 8;

  /// Hue (0-360) of a hex color — hueOf port.
  static int hueOf(String hex) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length < 6) return 0;
    final rgb = int.tryParse(clean.substring(0, 6), radix: 16) ?? 0;
    final r = ((rgb >> 16) & 0xFF) / 255.0;
    final g = ((rgb >> 8) & 0xFF) / 255.0;
    final b = (rgb & 0xFF) / 255.0;
    final max = [r, g, b].reduce((a, b2) => a > b2 ? a : b2);
    final min = [r, g, b].reduce((a, b2) => a < b2 ? a : b2);
    if (max == min) return 0;
    final d = max - min;
    double h;
    if (max == r) {
      h = ((g - b) / d + (g < b ? 6.0 : 0.0));
    } else if (max == g) {
      h = ((b - r) / d + 2.0);
    } else {
      h = ((r - g) / d + 4.0);
    }
    h /= 6.0;
    final deg = (h * 360).round();
    return ((deg % 360) + 360) % 360;
  }

  /// Dark scheme seeded from [hex]'s hue (buildDarkScheme port).
  static ColorScheme dark(String hex, {bool amoled = false}) {
    final h = hueOf(hex);
    final hT = (h + 60) % 360;
    return _dark(
      primaryHue: h,
      secondaryHue: h,
      tertiaryHue: hT,
      neutralHue: h,
      amoled: amoled,
    );
  }

  /// Light scheme seeded from [hex]'s hue (buildLightScheme port).
  static ColorScheme light(String hex) {
    final h = hueOf(hex);
    final hT = (h + 60) % 360;
    return _light(
      primaryHue: h,
      secondaryHue: h,
      tertiaryHue: hT,
      neutralHue: h,
    );
  }

  /// Pure grayscale dark scheme (buildMonochromeDarkScheme port).
  static ColorScheme monochromeDark({bool amoled = false}) => _dark(
    primaryHue: 0,
    secondaryHue: 0,
    tertiaryHue: 0,
    neutralHue: 0,
    amoled: amoled,
    monochrome: true,
  );

  static ColorScheme _dark({
    required int primaryHue,
    required int secondaryHue,
    required int tertiaryHue,
    required int neutralHue,
    required bool amoled,
    bool monochrome = false,
  }) {
    final cP = monochrome ? 0 : _chromaPrimary;
    final cS = monochrome ? 0 : _chromaSecondary;
    final cT = monochrome ? 0 : _chromaTertiary;
    final cN = monochrome ? 0 : _chromaNeutral;
    final cNV = monochrome ? 0 : _chromaNeutralVariant;

    final bgL = amoled ? 0 : 6;
    final sc1L = amoled ? 4 : 11;
    final sc2L = amoled ? 8 : 16;
    final sc3L = amoled ? 12 : 20;

    final backgroundCol =
    amoled ? const Color(0xFF000000) : hsl(neutralHue, cN, bgL);
    final surfaceLowCol =
    amoled ? const Color(0xFF000000) : hsl(neutralHue, cN, bgL);
    final surfaceLowestCol =
    amoled ? const Color(0xFF000000) : hsl(neutralHue, cN, bgL - 2 < 0 ? 0 : bgL - 2);

    return ColorScheme(
      brightness: Brightness.dark,
      primary: hsl(primaryHue, cP, 82),
      onPrimary: hsl(primaryHue, cP, 16),
      primaryContainer:
      hsl(primaryHue, cP, amoled ? 24 : 30),
      onPrimaryContainer: hsl(primaryHue, (cP - 5) < 0 ? 0 : cP - 5, 90),
      secondary: hsl(secondaryHue, cS, 80),
      onSecondary: hsl(secondaryHue, cS, 16),
      secondaryContainer:
      hsl(secondaryHue, cS, amoled ? 22 : 28),
      onSecondaryContainer:
      hsl(secondaryHue, (cS - 4) < 0 ? 0 : cS - 4, 90),
      tertiary: hsl(tertiaryHue, cT, 80),
      onTertiary: hsl(tertiaryHue, cT, 16),
      tertiaryContainer:
      hsl(tertiaryHue, cT, amoled ? 22 : 28),
      onTertiaryContainer:
      hsl(tertiaryHue, (cT - 6) < 0 ? 0 : cT - 6, 90),
      error: hsl(0, 45, 80),
      errorContainer: hsl(0, 30, 25),
      onErrorContainer: hsl(0, 25, 88),
      onError: hsl(0, 45, 16),
      background: backgroundCol,
      onBackground: hsl(neutralHue, cNV, 90),
      surface: backgroundCol,
      onSurface: hsl(neutralHue, cNV, 90),
      surfaceContainer: hsl(neutralHue, cN, sc1L),
      surfaceContainerHigh: hsl(neutralHue, cN, sc2L),
      surfaceContainerHighest: hsl(neutralHue, cN, sc3L),
      surfaceContainerLow: surfaceLowCol,
      surfaceContainerLowest: surfaceLowestCol,
      surfaceVariant: hsl(neutralHue, cNV, sc2L + 4),
      onSurfaceVariant: hsl(neutralHue, cNV, 80),
      outline: hsl(neutralHue, cNV, 60),
      outlineVariant: hsl(neutralHue, cNV, 28),
      inverseSurface: hsl(neutralHue, cNV, 90),
      onInverseSurface: hsl(neutralHue, cNV, 20),
      inversePrimary: hsl(primaryHue, cP, 40),
      scrim: const Color(0xFF000000),
      // Compose has no dim/bright roles; sane fills documented here.
      surfaceDim: backgroundCol,
      surfaceBright: hsl(neutralHue, cN, sc2L),
    );
  }

  static ColorScheme _light({
    required int primaryHue,
    required int secondaryHue,
    required int tertiaryHue,
    required int neutralHue,
    bool monochrome = false,
  }) {
    final cP = monochrome ? 0 : _chromaPrimary + 15;
    final cS = monochrome ? 0 : _chromaSecondary + 8;
    final cT = monochrome ? 0 : _chromaTertiary + 12;
    final cN = monochrome ? 0 : 4;
    final cNV = monochrome ? 0 : 6;

    return ColorScheme(
      brightness: Brightness.light,
      primary: hsl(primaryHue, cP, 40),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: hsl(primaryHue, cP, 90),
      onPrimaryContainer: hsl(primaryHue, cP, 10),
      secondary: hsl(secondaryHue, cS, 40),
      onSecondary: const Color(0xFFFFFFFF),
      secondaryContainer: hsl(secondaryHue, cS, 90),
      onSecondaryContainer: hsl(secondaryHue, cS, 10),
      tertiary: hsl(tertiaryHue, cT, 40),
      onTertiary: const Color(0xFFFFFFFF),
      tertiaryContainer: hsl(tertiaryHue, cT, 90),
      onTertiaryContainer: hsl(tertiaryHue, cT, 10),
      error: hsl(0, 70, 40),
      errorContainer: hsl(0, 70, 90),
      onErrorContainer: hsl(0, 70, 12),
      onError: const Color(0xFFFFFFFF),
      background: hsl(neutralHue, cN, 98),
      onBackground: hsl(neutralHue, cNV, 10),
      surface: hsl(neutralHue, cN, 98),
      onSurface: hsl(neutralHue, cNV, 10),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: hsl(neutralHue, cN, 96),
      surfaceContainer: hsl(neutralHue, cN, 94),
      surfaceContainerHigh: hsl(neutralHue, cN, 92),
      surfaceContainerHighest: hsl(neutralHue, cN, 90),
      surfaceVariant: hsl(neutralHue, cNV, 90),
      onSurfaceVariant: hsl(neutralHue, cNV, 30),
      outline: hsl(neutralHue, cNV, 50),
      outlineVariant: hsl(neutralHue, cNV, 80),
      inverseSurface: hsl(neutralHue, cNV, 20),
      onInverseSurface: hsl(neutralHue, cNV, 95),
      inversePrimary: hsl(primaryHue, cP, 80),
      scrim: const Color(0xFF000000),
      surfaceDim: hsl(neutralHue, cN, 90),
      surfaceBright: hsl(neutralHue, cN, 98),
    );
  }

  /// CSS hsl() → Color. Must match browsers exactly (q/p algorithm).
  static Color hsl(int h, int s, int l) {
    final hf = (((h % 360) + 360) % 360) / 360.0;
    final sf = (s.clamp(0, 100)) / 100.0;
    final lf = (l.clamp(0, 100)) / 100.0;
    if (sf == 0.0) {
      return Color.fromARGB(255, (lf * 255).round(), (lf * 255).round(),
          (lf * 255).round());
    }
    final q = lf < 0.5 ? lf * (1 + sf) : lf + sf - lf * sf;
    final p = 2 * lf - q;
    double hueToRgb(double t) {
      var tt = t;
      if (tt < 0) tt += 1;
      if (tt > 1) tt -= 1;
      if (tt < 1.0 / 6.0) return p + (q - p) * 6 * tt;
      if (tt < 1.0 / 2.0) return q;
      if (tt < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - tt) * 6;
      return p;
    }

    final r = hueToRgb(hf + 1.0 / 3.0);
    final g = hueToRgb(hf);
    final b = hueToRgb(hf - 1.0 / 3.0);
    return Color.fromARGB(
        255, (r * 255).round(), (g * 255).round(), (b * 255).round());
  }
}