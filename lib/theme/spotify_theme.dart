import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_controller.dart';
import 'zen_palette.dart';

export 'theme_controller.dart' show ZenThemeController, ZenThemeScope;
export 'zen_palette.dart';

/// App colours. Historically these were compile-time constants; they now
/// forward to the active [ZenPalette] so the whole app can be re-themed at
/// runtime (Settings → Appearance → Theme). The member names are kept so
/// existing screens did not need to change: `green` is the accent fill,
/// `highlight` the accent for text/icons.
class SpotifyColors {
  SpotifyColors._();

  static ZenPalette get _p => ZenThemeController.palette;

  static Color get background => _p.background;
  static Color get surface => _p.surface;
  static Color get surfaceLight => _p.surfaceLight;
  static Color get surfaceLighter => _p.surfaceLighter;

  static Color get green => _p.primary;
  static Color get greenDark => _p.primaryDark;
  static Color get highlight => _p.highlight;
  static Color get onAccent => _p.onPrimary;

  static Color get textPrimary => _p.textPrimary;
  static Color get textSecondary => _p.textSecondary;
  static Color get textTertiary => _p.textTertiary;
}

class SpotifyTheme {
  /// Heading font — Inter, set heavy, for the clean Spotify-style look
  /// (was Playfair Display).
  static const headingFont = 'Inter';

  /// Body/UI font — Inter.
  static const bodyFont = 'Inter';

  static ThemeData dark() {
    // google_fonts: no-argument calls fetch + register both families
    // (version-proof API). Plain fontFamily strings resolve to them.
    GoogleFonts.inter();

    final scheme = ColorScheme.dark(
      primary: SpotifyColors.green,
      onPrimary: SpotifyColors.onAccent,
      secondary: SpotifyColors.highlight,
      onSecondary: SpotifyColors.onAccent,
      tertiary: SpotifyColors.highlight,
      surface: SpotifyColors.background,
      onSurface: SpotifyColors.textPrimary,
      onSurfaceVariant: SpotifyColors.textSecondary,
      surfaceContainerLowest: SpotifyColors.background,
      surfaceContainerLow: SpotifyColors.surface,
      surfaceContainer: SpotifyColors.surface,
      surfaceContainerHigh: SpotifyColors.surfaceLight,
      surfaceContainerHighest: SpotifyColors.surfaceLighter,
      outline: SpotifyColors.textTertiary,
      outlineVariant: SpotifyColors.surfaceLighter,
      inversePrimary: SpotifyColors.greenDark,
    );

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
      appBarTheme: AppBarTheme(
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
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: SpotifyColors.surface,
        selectedItemColor: SpotifyColors.highlight,
        unselectedItemColor: SpotifyColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: SpotifyColors.highlight,
        inactiveTrackColor: SpotifyColors.surfaceLighter,
        thumbColor: SpotifyColors.highlight,
        overlayColor: SpotifyColors.highlight.withAlpha(0x33),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
      ),
      iconTheme: IconThemeData(color: SpotifyColors.textPrimary),
      dividerColor: SpotifyColors.surfaceLighter,
      // NOTE: no const — this Flutter version's DialogThemeData
      // constructor is not const.
      dialogTheme: DialogThemeData(
        backgroundColor: SpotifyColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          color: SpotifyColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          fontFamily: headingFont,
        ),
        contentTextStyle: TextStyle(
          color: SpotifyColors.textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: SpotifyColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: SpotifyColors.surface,
        modalBarrierColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: false,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: SpotifyColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        textStyle: TextStyle(color: SpotifyColors.textPrimary, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SpotifyColors.surfaceLighter,
        contentTextStyle: TextStyle(color: SpotifyColors.textPrimary, fontSize: 14),
        actionTextColor: SpotifyColors.highlight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: SpotifyColors.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: SpotifyColors.surfaceLight,
        headerForegroundColor: SpotifyColors.textPrimary,
        dayStyle: TextStyle(color: SpotifyColors.textPrimary),
        yearStyle: TextStyle(color: SpotifyColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: SpotifyColors.surface,
        dialBackgroundColor: SpotifyColors.surfaceLight,
        hourMinuteColor: SpotifyColors.surfaceLight,
        hourMinuteTextColor: SpotifyColors.textPrimary,
        dialHandColor: SpotifyColors.highlight,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: SpotifyColors.surface,
        selectedColor: SpotifyColors.surfaceLighter,
        labelStyle: TextStyle(color: SpotifyColors.textPrimary, fontSize: 13),
        side: BorderSide(color: SpotifyColors.surfaceLighter),
        shape: StadiumBorder(),
      ),
      tooltipTheme: TooltipThemeData(
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
          foregroundColor: SpotifyColors.onAccent,
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
        side: BorderSide(color: SpotifyColors.textTertiary, width: 1.5),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: SpotifyColors.highlight,
        linearTrackColor: SpotifyColors.surfaceLighter,
      ),
    );
  }
}

/// A subtle vertical gradient that fades from a tinted top to the background.
class SpotifyGradient extends StatelessWidget {
  final Widget child;
  final Color? tint;

  const SpotifyGradient({
    super.key,
    required this.child,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tint ?? SpotifyColors.surface,
            SpotifyColors.background,
          ],
          stops: const [0.0, 0.6],
        ),
      ),
      child: child,
    );
  }
}