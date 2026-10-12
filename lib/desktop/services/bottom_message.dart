// ZenMusic Desktop — ported from Echo Music (GPL-3.0). ZenMusic remains GPL-3.0.
// Known benign analyzer item: withOpacity deprecation hints (verbatim upstream).

import 'package:flutter/material.dart';

import '../themes/text_styles.dart';
import '../utils/adaptive_widgets/theme.dart';

class BottomMessage {
  static void showText(BuildContext context, String text,
      {Duration duration = const Duration(milliseconds: 1500)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: smallTextStyle(context, bold: false, opacity: 0.8).copyWith(
            color: AdaptiveTheme.of(context).inactiveBackgroundColor,
          ),
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: AdaptiveTheme.of(context).primaryColor.withOpacity(0.9),
      ),
    );
  }
}