import 'package:flutter/material.dart';

/// Shape.kt port — app.css radius scale + expressive extras + the
/// M3 Expressive 10-step primitives. Lw components reference these
/// directly (Flutter has no global Shapes object).
class LwShapes {
  LwShapes._();

  // app.css scale
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;

  // Expressive extras
  static const double hero = 32;
  static const double heroInner = 24;
  static const double statPill = 16;
  static const double listContainer = 28;
  static const double nowPlayingCard = 18;
  static const double trackRow = 16;
  static const double artwork = 12;

  // M3 Expressive scale
  static const double m3None = 0;
  static const double m3ExtraSmall = 4;
  static const double m3Small = 8;
  static const double m3Medium = 12;
  static const double m3Large = 16;
  static const double m3LargeIncreased = 20;
  static const double m3ExtraLarge = 28;
  static const double m3ExtraLargeIncreased = 32;
  static const double m3ExtraExtraLarge = 48;
}