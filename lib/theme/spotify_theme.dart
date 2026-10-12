import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/lw/lw_scheme.dart';

/// ZenMusic — LastWave Material You dark palette.
///
/// Every constant below is the exact output of LastWave's
/// Md3SchemeBuilder algorithm (ported to LwScheme, GPL-3.0) for seed
/// hue 231 — the Material You blue. Chroma levels (primary 30,
/// secondary 14, tertiary 22, neutral 5, NV 8) and the dark
/// lightness ladder (bg 6 / sc1 11 / sc2 16 / sc3 20) are
/// LastWave's exact values.
///
/// To re-seed the whole palette: change [seedHex], rebuild the scheme
/// with LwScheme.dark(seedHex), and re-bake these constants from its
/// output. All screens (SpotifyColors callers AND Theme.of(context)
/// consumers) follow together.
class SpotifyColors {
  // Seed used to derive this palette (Material You blue).
  static const seedHex = '3F51B5';

  // Neutral surfaces (hsl 231, 5%, lightness ladder 6/11/16/20).
  static const background = Color(0xFF0F0F10);
  static const surface = Color(0xFF1B1B1D);
  static const surfaceLight = Color(0xFF27272B); // Card / scHigh
  static const surfaceLighter = Color(0xFF303136); // scHighest

  // Primary (hsl 231, 30%, 82%) — soft periwinkle fill.
  static const green = Color(0xFFC3C7DF); // primary
  static const greenDark = Color(0xFF475185); // inversePrimary (deep)
  static const highlight = Color(0xFFD4C1D7); // tertiary accent

  // Text (hsl 231, 8%): 90 / 80 / 60 lightness.
  static const textPrimary = Color(0xFFE3E4E8);
  static const textSecondary = Color(0xFFC8C8D0);
  static const textTertiary = Color(0xFF9191A1);
}

class SpotifyTheme {
  /// Heading font — Playfair Display.
  static const headingFont = 'PlayfairDisplay';

  /// Body/UI font — Inter.
  static const bodyFont = 'Inter';

  static ThemeData dark() {
    // google_fonts: no-argument calls fetch + register both families
    // (version-proof API). Plain fontFamily strings resolve to them.
    GoogleFonts.inter();
    GoogleFonts.playfairDisplay();

    // The ColorScheme is generated at runtime by LastWave's ported
    // Md3SchemeBuilder — guaranteed identical to the baked SpotifyColors
    // above (same algorithm, same seed). Theme.of(context) consumers and
    // SpotifyColors consumers always agree.
    final scheme = LwScheme.dark(SpotifyColors.seedHex);

    final text = ThemeData.dark(useMaterial3: true).textTheme.apply(
      bodyColor: SpotifyColors.textPrimary,
      displayColor: SpotifyColors.textPrimary,
      fontFamily: bodyFont,
    );

    final headings = text.copyWith(
      displayLarge: text.displayLarge?.copyWith(fontFamily: headingFont),
      displayMedium: text.displayMedium?.copyWith(fontFamily: headingFont),
      displaySmall: text.displaySmall?.copyWith(fontFamily: headingFont),
      headlineLarge: text.headlineLarge?.copyWith(fontFamily: headingFont),
      headlineMedium: text.headlineMedium?.copyWith(fontFamily: headingFont),
      headlineSmall: text.headlineSmall?.copyWith(fontFamily: headingFont),
      titleLarge: text.titleLarge?.copyWith(fontFamily: headingFont),
    );

    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: SpotifyColors.background,
      colorScheme: scheme,
      textTheme: headings,
      appBarTheme: const AppBarTheme(
        backgroundColor: SpotifyColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: SpotifyColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          fontFamily: headingFont,
        ),
        iconTheme: IconThemeData(color: SpotifyColors.textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: SpotifyColors.surface,
        selectedItemColor: SpotifyColors.highlight,
        unselectedItemColor: SpotifyColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        activeTrackColor: SpotifyColors.highlight,
        inactiveTrackColor: SpotifyColors.surfaceLighter,
        thumbColor: SpotifyColors.highlight,
        overlayColor: Color(0x33C3C7DF),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
      ),
      iconTheme: const IconThemeData(color: SpotifyColors.textPrimary),
      dividerColor: SpotifyColors.surfaceLighter,
      // NOTE: no const — this Flutter version's DialogThemeData
      // constructor is not const.
      dialogTheme: DialogThemeData(
        backgroundColor: SpotifyColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(
          color: SpotifyColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          fontFamily: headingFont,
        ),
        contentTextStyle: const TextStyle(
          color: SpotifyColors.textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SpotifyColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: SpotifyColors.surface,
        modalBarrierColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: false,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: SpotifyColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        textStyle: TextStyle(color: SpotifyColors.textPrimary, fontSize: 14),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: SpotifyColors.surfaceLighter,
        contentTextStyle: TextStyle(color: SpotifyColors.textPrimary, fontSize: 14),
        actionTextColor: SpotifyColors.highlight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: SpotifyColors.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: SpotifyColors.surfaceLight,
        headerForegroundColor: SpotifyColors.textPrimary,
        dayStyle: TextStyle(color: SpotifyColors.textPrimary),
        yearStyle: TextStyle(color: SpotifyColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: SpotifyColors.surface,
        dialBackgroundColor: SpotifyColors.surfaceLight,
        hourMinuteColor: SpotifyColors.surfaceLight,
        hourMinuteTextColor: SpotifyColors.textPrimary,
        dialHandColor: SpotifyColors.highlight,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: SpotifyColors.surface,
        selectedColor: SpotifyColors.surfaceLighter,
        labelStyle: TextStyle(color: SpotifyColors.textPrimary, fontSize: 13),
        side: BorderSide(color: SpotifyColors.surfaceLighter),
        shape: StadiumBorder(),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: SpotifyColors.surfaceLighter,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        textStyle: TextStyle(color: SpotifyColors.textPrimary, fontSize: 12),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SpotifyColors.highlight,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SpotifyColors.green,
          foregroundColor: SpotifyColors.background,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected)
            ? SpotifyColors.background
            : SpotifyColors.textTertiary),
        trackColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected)
            ? SpotifyColors.green
            : SpotifyColors.surfaceLighter),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected)
            ? SpotifyColors.green
            : Colors.transparent),
        side: const BorderSide(color: SpotifyColors.textTertiary, width: 1.5),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SpotifyColors.highlight,
        linearTrackColor: SpotifyColors.surfaceLighter,
      ),
    );
  }
}

/// A subtle vertical gradient that fades from a tinted top to the background.
class SpotifyGradient extends StatelessWidget {
  final Widget child;
  final Color tint;

  const SpotifyGradient({
    super.key,
    required this.child,
    this.tint = SpotifyColors.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tint,
            SpotifyColors.background,
          ],
          stops: const [0.0, 0.6],
        ),
      ),
      child: child,
    );
  }
}