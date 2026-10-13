import 'package:flutter/material.dart';

/// One complete colour set for the app. Every screen reads its colours
/// through [SpotifyColors] (spotify_theme.dart), which forwards to the
/// active palette — so swapping the palette re-skins the whole app.
@immutable
class ZenPalette {
  const ZenPalette({
    required this.id,
    required this.name,
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.surfaceLighter,
    required this.primary,
    required this.primaryDark,
    required this.highlight,
    required this.onPrimary,
    this.textPrimary = const Color(0xFFFFFFFF),
    this.textSecondary = const Color(0xFFB3B3B3),
    this.textTertiary = const Color(0xFF7A7A7A),
  });

  final String id;
  final String name;

  /// Page background.
  final Color background;

  /// Cards, sheets, mini player.
  final Color surface;
  final Color surfaceLight;
  final Color surfaceLighter;

  /// Accent fill (play button, switches, selected states).
  final Color primary;
  final Color primaryDark;

  /// Accent for text/icons/sliders on dark surfaces.
  final Color highlight;

  /// Text/icon colour drawn on top of [primary].
  final Color onPrimary;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  ZenPalette copyWith({String? id, String? name}) => ZenPalette(
        id: id ?? this.id,
        name: name ?? this.name,
        background: background,
        surface: surface,
        surfaceLight: surfaceLight,
        surfaceLighter: surfaceLighter,
        primary: primary,
        primaryDark: primaryDark,
        highlight: highlight,
        onPrimary: onPrimary,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        textTertiary: textTertiary,
      );

  /// Builds a dark palette around any accent colour — used for
  /// "Match album art" and custom accent picks.
  factory ZenPalette.fromAccent(
    Color accent, {
    String id = 'album',
    String name = 'Match album art',
    bool amoled = false,
  }) {
    final hsl = HSLColor.fromColor(accent);
    final h = hsl.hue;
    // Keep the accent readable on a near-black background.
    final s = hsl.saturation.clamp(0.45, 0.85);
    Color tone(double sat, double light) =>
        HSLColor.fromAHSL(1, h, sat, light).toColor();
    final primary = tone(s, 0.58);
    return ZenPalette(
      id: id,
      name: name,
      background: amoled ? const Color(0xFF000000) : tone(0.18, 0.06),
      surface: amoled ? const Color(0xFF0B0B0B) : tone(0.16, 0.10),
      surfaceLight: amoled ? const Color(0xFF161616) : tone(0.14, 0.15),
      surfaceLighter: amoled ? const Color(0xFF202020) : tone(0.12, 0.19),
      primary: primary,
      primaryDark: tone(s, 0.40),
      highlight: tone(s, 0.70),
      onPrimary: const Color(0xFF0A0A0A),
      textPrimary: const Color(0xFFFFFFFF),
      textSecondary: tone(0.08, 0.74),
      textTertiary: tone(0.06, 0.52),
    );
  }
}

/// Built-in theme presets, in the order the picker shows them.
class ZenPalettes {
  ZenPalettes._();

  static const classic = ZenPalette(
    id: 'classic',
    name: 'Classic Green',
    background: Color(0xFF121212),
    surface: Color(0xFF181818),
    surfaceLight: Color(0xFF242424),
    surfaceLighter: Color(0xFF2E2E2E),
    primary: Color(0xFF1DB954),
    primaryDark: Color(0xFF168D40),
    highlight: Color(0xFF1ED760),
    onPrimary: Color(0xFF000000),
  );

  static const amoled = ZenPalette(
    id: 'amoled',
    name: 'AMOLED Black',
    background: Color(0xFF000000),
    surface: Color(0xFF0B0B0B),
    surfaceLight: Color(0xFF161616),
    surfaceLighter: Color(0xFF202020),
    primary: Color(0xFF1ED760),
    primaryDark: Color(0xFF168D40),
    highlight: Color(0xFF1ED760),
    onPrimary: Color(0xFF000000),
  );

  /// The palette ZenMusic shipped with (LastWave periwinkle).
  static const zen = ZenPalette(
    id: 'zen',
    name: 'Zen Periwinkle',
    background: Color(0xFF0F0F10),
    surface: Color(0xFF1B1B1D),
    surfaceLight: Color(0xFF27272B),
    surfaceLighter: Color(0xFF303136),
    primary: Color(0xFFC3C7DF),
    primaryDark: Color(0xFF475185),
    highlight: Color(0xFFD4C1D7),
    onPrimary: Color(0xFF0F0F10),
    textPrimary: Color(0xFFE3E4E8),
    textSecondary: Color(0xFFC8C8D0),
    textTertiary: Color(0xFF9191A1),
  );

  static const midnight = ZenPalette(
    id: 'midnight',
    name: 'Midnight',
    background: Color(0xFF0B1020),
    surface: Color(0xFF131A2D),
    surfaceLight: Color(0xFF1C243C),
    surfaceLighter: Color(0xFF262F4B),
    primary: Color(0xFF6C8CFF),
    primaryDark: Color(0xFF3F5BC4),
    highlight: Color(0xFF93A9FF),
    onPrimary: Color(0xFF0B1020),
    textSecondary: Color(0xFFB0B7CC),
    textTertiary: Color(0xFF737C96),
  );

  static const sunset = ZenPalette(
    id: 'sunset',
    name: 'Sunset',
    background: Color(0xFF140C0B),
    surface: Color(0xFF1F1412),
    surfaceLight: Color(0xFF2B1C19),
    surfaceLighter: Color(0xFF372421),
    primary: Color(0xFFFF7A45),
    primaryDark: Color(0xFFC4532A),
    highlight: Color(0xFFFFA06E),
    onPrimary: Color(0xFF140C0B),
    textSecondary: Color(0xFFCFB8B2),
    textTertiary: Color(0xFF8F7670),
  );

  static const ocean = ZenPalette(
    id: 'ocean',
    name: 'Ocean',
    background: Color(0xFF071318),
    surface: Color(0xFF0E1E25),
    surfaceLight: Color(0xFF162A33),
    surfaceLighter: Color(0xFF1F3640),
    primary: Color(0xFF2EC4B6),
    primaryDark: Color(0xFF1F8C82),
    highlight: Color(0xFF5FE3D6),
    onPrimary: Color(0xFF071318),
    textSecondary: Color(0xFFADC4C8),
    textTertiary: Color(0xFF6E878C),
  );

  static const rose = ZenPalette(
    id: 'rose',
    name: 'Rose',
    background: Color(0xFF140A0F),
    surface: Color(0xFF1F1118),
    surfaceLight: Color(0xFF2C1923),
    surfaceLighter: Color(0xFF38222E),
    primary: Color(0xFFFF5C8A),
    primaryDark: Color(0xFFC23A62),
    highlight: Color(0xFFFF87A8),
    onPrimary: Color(0xFF140A0F),
    textSecondary: Color(0xFFCEB3BE),
    textTertiary: Color(0xFF8E727D),
  );

  static const forest = ZenPalette(
    id: 'forest',
    name: 'Forest',
    background: Color(0xFF0B110C),
    surface: Color(0xFF131C14),
    surfaceLight: Color(0xFF1C281D),
    surfaceLighter: Color(0xFF253327),
    primary: Color(0xFF7BC96F),
    primaryDark: Color(0xFF4E8F45),
    highlight: Color(0xFF9EDC93),
    onPrimary: Color(0xFF0B110C),
    textSecondary: Color(0xFFB4C4B3),
    textTertiary: Color(0xFF738472),
  );

  static const violet = ZenPalette(
    id: 'violet',
    name: 'Neon Violet',
    background: Color(0xFF0E0A16),
    surface: Color(0xFF181122),
    surfaceLight: Color(0xFF231931),
    surfaceLighter: Color(0xFF2E213F),
    primary: Color(0xFFB57BFF),
    primaryDark: Color(0xFF7D48C9),
    highlight: Color(0xFFE63CFF),
    onPrimary: Color(0xFF0E0A16),
    textSecondary: Color(0xFFBDB2CC),
    textTertiary: Color(0xFF7D728C),
  );

  /// Sentinel id: palette follows the playing song's artwork.
  static const albumId = 'album';

  static const all = <ZenPalette>[
    classic,
    amoled,
    zen,
    midnight,
    sunset,
    ocean,
    rose,
    forest,
    violet,
  ];

  static ZenPalette byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => classic);
}
