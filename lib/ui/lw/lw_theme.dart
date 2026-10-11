import 'package:flutter/material.dart';
import 'lw_scheme.dart';

/// ThemeData builder over the ported scheme.
class LwThemes {
  LwThemes._();

  /// Default seed: ZenMusic's brass. Changing this one hex = full
  /// re-seed of every token (accent picker comes free later).
  static const String brassSeed = 'B8A34C';

  static ThemeData dark({String seedHex = brassSeed, bool amoled = false}) {
    final scheme = LwScheme.dark(seedHex, amoled: amoled);
    return ThemeData.from(
      colorScheme: scheme,
      useMaterial3: true,
    ).copyWith(
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static ThemeData light({String seedHex = brassSeed}) {
    final scheme = LwScheme.light(seedHex);
    return ThemeData.from(
      colorScheme: scheme,
      useMaterial3: true,
    ).copyWith(
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
    );
  }
}