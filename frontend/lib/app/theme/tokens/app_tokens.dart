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

/// Page width scale.
///
/// Screens used to hard-code their own cap (1180 here, 1280 there, 1120 on the
/// profile), so a wide monitor showed a narrow column stranded in the middle of
/// an empty page and no two screens agreed on how narrow. Widths are resolved
/// from the viewport instead: the column grows with the window until it hits a
/// cap chosen for readability, and the leftover space becomes an even margin.
class AppLayout {
  /// Window width at which the desktop chrome — branded rail plus top bar —
  /// replaces the tablet rail.
  static const double desktopBreakpoint = 1024;

  /// The branded rail, plus the hairline divider beside it.
  static const double railWidth = 92;
  static const double _railAndDivider = railWidth + 1;

  /// Width at which a *page* adopts its desktop composition.
  ///
  /// A page inside the shell is a rail narrower than the window, so at the
  /// window breakpoint it never sees more than this. Measuring page layout
  /// against [desktopBreakpoint] instead left a band of window sizes where the
  /// chrome said desktop while the page inside it was still drawing its
  /// phone-shaped, single-column self.
  static const double contentDesktopBreakpoint =
      desktopBreakpoint - _railAndDivider;

  /// Narrowest a page column can be and still carry [sideColumn] next to a
  /// usable second column.
  static const double twoColumnMin = 700;

  /// Widest a content column may grow. Past this, line length stops being
  /// comfortable and extra pixels are better spent on the margin.
  static const double contentMax = 1440;

  /// Cap for reading-first content: forms, settings, a column of prose. Wider
  /// than this a paragraph runs past a comfortable line length.
  static const double narrowMax = 760;

  /// Width of the ingredients column beside the steps on a wide recipe page.
  static const double sideColumn = 340;

  /// Phone margin. Unchanged from the pre-token layout so handsets keep their
  /// existing edge spacing; only desktop widths open up.
  static const double compact = AppSpacing.md;
  static const double tight = 24;
  static const double regular = 32;
  static const double roomy = 48;

  /// Horizontal page margin for a viewport of [width].
  static double gutter(double width) => width >= 1600
      ? roomy
      : width >= 1280
          ? regular
          : width >= desktopBreakpoint
              ? tight
              : compact;
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
  /// Shared UI/body family across every brand preset. Ships real 400–800
  /// instances and covers Ukrainian Cyrillic (ҐЄІЇ), so body text renders in
  /// the family it asks for instead of dropping into [bodyFallback].
  static const String body = 'Manrope';

  /// Appended to body styles so glyphs outside the body charset still resolve.
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
