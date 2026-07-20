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

/// The eight semantic colour roles, resolved for one [Brightness].
///
/// Widgets must read these through `context.semantic` (or the [ThemeExtension])
/// rather than referencing raw values, so that a surface renders correctly in
/// both themes and under any tenant [BrandConfig].
class SemanticColors extends ThemeExtension<SemanticColors> {
  const SemanticColors({
    required this.background,
    required this.surface,
    required this.surfaceStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.warning,
    required this.error,
  });

  final Color background;
  final Color surface;
  final Color surfaceStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color warning;
  final Color error;

  /// Handoff Spec §1 — light column.
  static const SemanticColors light = SemanticColors(
    background: Color(0xFFF5EEE1),
    surface: Color(0xFFFDF8EE),
    surfaceStrong: Color(0xFFEBE0CC),
    textPrimary: Color(0xFF1C1710),
    textSecondary: Color(0xFF7C7159),
    success: Color(0xFF3E6B4A),
    warning: Color(0xFFB0832E),
    error: Color(0xFFA8362A),
  );

  /// Handoff Spec §1 — dark column.
  static const SemanticColors dark = SemanticColors(
    background: Color(0xFF16130F),
    surface: Color(0xFF221D16),
    surfaceStrong: Color(0xFF2E2820),
    textPrimary: Color(0xFFF3E9DA),
    textSecondary: Color(0xFFB9AC98),
    success: Color(0xFF7A9E7E),
    warning: Color(0xFFC9A24B),
    error: Color(0xFFD67A6B),
  );

  static SemanticColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Data/mono role (Handoff §1 typography): numeric metadata and codes.
  TextStyle get dataLabel => TextStyle(
        fontFamily: AppFonts.data,
        fontSize: 11,
        height: 1.3,
        letterSpacing: 0,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      );

  TextStyle get dataBody => TextStyle(
        fontFamily: AppFonts.data,
        fontSize: 13,
        height: 1.3,
        letterSpacing: 0,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      );

  @override
  SemanticColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? success,
    Color? warning,
    Color? error,
  }) =>
      SemanticColors(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceStrong: surfaceStrong ?? this.surfaceStrong,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        error: error ?? this.error,
      );

  @override
  SemanticColors lerp(ThemeExtension<SemanticColors>? other, double t) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceStrong: Color.lerp(surfaceStrong, other.surfaceStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

extension SemanticColorsContext on BuildContext {
  /// The semantic palette resolved for the ambient theme brightness.
  SemanticColors get semantic =>
      Theme.of(this).extension<SemanticColors>() ??
      SemanticColors.of(Theme.of(this).brightness);
}

class AppFonts {
  /// Shared UI/body family across every brand preset.
  static const String body = 'Figtree';

  /// Appended to body styles so Cyrillic glyphs always resolve.
  static const List<String> bodyFallback = ['Golos Text'];

  /// Data/mono role.
  static const String data = 'JetBrains Mono';
}

/// Mode-independent product colours.
///
/// Semantic, brightness-aware roles live in [SemanticColors]; only values that
/// are the same in both themes (product tier gold, ink scene colours) belong
/// here. The light-mode aliases are retained so unmigrated widgets keep
/// compiling while screens move onto `context.semantic`.
class AppColorsV2 {
  static const Color bg = Color(0xFFF5EEE1);
  static const Color surface = Color(0xFFFDF8EE);
  static const Color surfaceStrong = Color(0xFFEBE0CC);
  static const Color textPrimary = Color(0xFF1C1710);
  static const Color textSecondary = Color(0xFF7C7159);

  /// Product-tier colour, deliberately not a tenant brand role.
  static const Color premiumGold = Color(0xFFD9A441);
  static const Color accent = premiumGold;
  static const Color accentDark = Color(0xFFC7902F);
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
