// ZenMusic Desktop — ported from Echo Music (GPL-3.0).
// Echo Music is Copyright (C) the Echo Music authors; this port and ZenMusic
// remain GPL-3.0 (https://github.com/vorlon-dev/Zen-music).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:zenmusic/desktop/services/settings_manager.dart';

extension DarkMode on BuildContext {
  /// is dark mode currently enabled?
  bool get isDarkMode {
    final brightness = watch<SettingsManager>().themeMode == ThemeMode.system
        ? MediaQuery.of(this).platformBrightness
        : watch<SettingsManager>().themeMode == ThemeMode.dark
        ? Brightness.dark
        : Brightness.light;
    return brightness == Brightness.dark;
  }

  bool get isDarkModeOnce {
    final brightness = read<SettingsManager>().themeMode == ThemeMode.system
        ? MediaQuery.of(this).platformBrightness
        : read<SettingsManager>().themeMode == ThemeMode.dark
        ? Brightness.dark
        : Brightness.light;
    return brightness == Brightness.dark;
  }

  Color get subtitleColor =>
      isDarkMode ? Colors.white.withAlpha(150) : Colors.black.withAlpha(150);
  Color get bottomModalBackgroundColor => isDarkMode
      ? Color.alphaBlend(Colors.black.withAlpha(220), Colors.white)
      : Colors.white;
}

extension StringMani on String {
  String get breakWord {
    String breakWord = '';
    for (var element in runes) {
      breakWord += String.fromCharCode(element);
      breakWord += '\u200B';
    }
    return breakWord;
  }
}