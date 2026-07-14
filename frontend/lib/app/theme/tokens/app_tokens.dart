import 'package:flutter/material.dart';

class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 56;
}

class AppRadius {
  static const BorderRadius sm = BorderRadius.all(Radius.circular(8));
  static const BorderRadius md = BorderRadius.all(Radius.circular(12));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(16));
  static const BorderRadius xl = BorderRadius.all(Radius.circular(24));
}

class AppElevation {
  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 2;
  static const double level3 = 4;
}

class AppColorsV2 {
  static const Color bg = Color(0xFFF5EEE1);
  static const Color surface = Color(0xFFFDF8EE);
  static const Color surfaceStrong = Color(0xFFEBE0CC);
  static const Color textPrimary = Color(0xFF1C1710);
  static const Color textSecondary = Color(0xFF7C7159);
  static const Color accent = Color(0xFFA87B24);
  static const Color accentDark = Color(0xFF7A5A1A);
  static const Color ink = Color(0xFF16130F);
  static const Color onInk = Color(0xFFF3E9DA);
  static const Color success = Color(0xFF3E6B4A);
  static const Color warning = Color(0xFFB0832E);
  static const Color error = Color(0xFFA8362A);
}

class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}
