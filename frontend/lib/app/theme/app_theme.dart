import 'package:flutter/material.dart';

import '../../core/branding/brand_config.dart';
import 'brand_theme.dart';
import 'component_themes.dart';
import 'tokens/app_tokens.dart';

class AppThemeV2 {
  static ThemeData light(BrandConfig brandConfig) => _build(
        brand: BrandThemeExtension.fromConfig(brandConfig),
        brightness: Brightness.light,
      );

  static ThemeData dark(BrandConfig brandConfig) => _build(
        brand: BrandThemeExtension.fromConfig(brandConfig),
        brightness: Brightness.dark,
      );

  /// The dark theme for the same brand as [base], regardless of the ambient
  /// [ThemeMode]. Used by the permanently dark scenes (camera flow, login,
  /// paywall) per the Handoff Spec.
  static ThemeData forcedDark(ThemeData base) {
    final brand = base.extension<BrandThemeExtension>();
    if (brand == null) return base;
    return _build(brand: brand, brightness: Brightness.dark);
  }

  static ThemeData _build({
    required BrandThemeExtension brand,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    final semantic = SemanticColors.of(brightness);
    final background = semantic.background;
    final surface = semantic.surface;
    final onSurface = semantic.textPrimary;
    final secondaryText = semantic.textSecondary;
    final accent = isDark ? brand.accentOnDark : brand.accent;
    final primary = accent;
    final lightPrimary =
        brand.lightCtaMode == 'accentFill' ? primary : AppColorsV2.ink;
    final cta = isDark ? primary : lightPrimary;
    final onCta = isDark
        ? AppColorsV2.ink
        : brand.lightCtaMode == 'accentFill'
            ? brand.onAccent
            : AppColorsV2.onInk;
    final primaryContainer = Color.alphaBlend(
      accent.withOpacity(isDark ? .20 : .13),
      semantic.surfaceRaised,
    );
    final errorContainer = Color.alphaBlend(
      semantic.error.withOpacity(isDark ? .20 : .11),
      semantic.surfaceRaised,
    );
    final surfaceDim = isDark ? semantic.background : const Color(0xFFE9E2D8);
    final surfaceBright =
        isDark ? const Color(0xFF3A3329) : semantic.surfaceRaised;
    final surfaceContainerLowest =
        isDark ? const Color(0xFF15120E) : semantic.surfaceRaised;
    final surfaceContainerLow = semantic.surface;
    final surfaceContainer =
        isDark ? const Color(0xFF272119) : const Color(0xFFF6F1EA);
    final surfaceContainerHigh =
        isDark ? semantic.surfaceStrong : const Color(0xFFEFE8DE);
    final surfaceContainerHighest =
        isDark ? const Color(0xFF3A3329) : semantic.surfaceStrong;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: cta,
      onPrimary: onCta,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onSurface,
      secondary: accent,
      onSecondary: isDark ? AppColorsV2.ink : brand.onAccent,
      secondaryContainer: primaryContainer,
      onSecondaryContainer: onSurface,
      tertiary: semantic.warning,
      onTertiary: AppColorsV2.ink,
      tertiaryContainer: Color.alphaBlend(
        semantic.warning.withOpacity(isDark ? .20 : .12),
        semantic.surfaceRaised,
      ),
      onTertiaryContainer: onSurface,
      error: semantic.error,
      onError: isDark ? AppColorsV2.ink : Colors.white,
      errorContainer: errorContainer,
      onErrorContainer: onSurface,
      surface: surface,
      onSurface: onSurface,
      surfaceDim: surfaceDim,
      surfaceBright: surfaceBright,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      onSurfaceVariant: secondaryText,
      outline: semantic.outline,
      outlineVariant: semantic.outlineVariant,
      shadow: isDark ? Colors.black : const Color(0xFF2A2116),
      scrim: Colors.black,
      inverseSurface: isDark
          ? SemanticColors.light.surfaceRaised
          : SemanticColors.dark.surface,
      onInverseSurface: isDark
          ? SemanticColors.light.textPrimary
          : SemanticColors.dark.textPrimary,
      inversePrimary: isDark ? brand.accent : brand.accentOnDark,
      surfaceTint: Colors.transparent,
    );
    final baseText =
        isDark ? Typography.whiteMountainView : Typography.blackMountainView;
    final textTheme = baseText.copyWith(
      headlineLarge: TextStyle(
          fontFamily: brand.displayFontFamily,
          fontSize: 40,
          height: 1.05,
          fontWeight: FontWeight.w700,
          color: onSurface),
      headlineMedium: TextStyle(
          fontFamily: brand.displayFontFamily,
          fontSize: 30,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: onSurface),
      headlineSmall: TextStyle(
          fontFamily: brand.displayFontFamily,
          fontSize: 24,
          height: 1.15,
          fontWeight: FontWeight.w700,
          color: onSurface),
      titleLarge: TextStyle(
          fontFamily: brand.displayFontFamily,
          fontSize: 22,
          height: 1.15,
          fontWeight: FontWeight.w600,
          color: onSurface),
      titleMedium: TextStyle(
          fontFamily: brand.bodyFontFamily,
          fontFamilyFallback: brand.bodyFontFallback,
          fontSize: 17,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: onSurface),
      titleSmall: TextStyle(
          fontFamily: brand.bodyFontFamily,
          fontFamilyFallback: brand.bodyFontFallback,
          fontSize: 15,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: onSurface),
      bodyLarge: TextStyle(
          fontFamily: brand.bodyFontFamily,
          fontFamilyFallback: brand.bodyFontFallback,
          fontSize: 16,
          height: 1.4,
          color: onSurface),
      bodyMedium: TextStyle(
          fontFamily: brand.bodyFontFamily,
          fontFamilyFallback: brand.bodyFontFallback,
          fontSize: 14,
          height: 1.4,
          color: onSurface),
      bodySmall: TextStyle(
          fontFamily: brand.bodyFontFamily,
          fontFamilyFallback: brand.bodyFontFallback,
          fontSize: 12,
          height: 1.3,
          color: secondaryText),
      labelSmall: TextStyle(
          fontFamily: brand.bodyFontFamily,
          fontFamilyFallback: brand.bodyFontFallback,
          fontSize: 11,
          letterSpacing: 0,
          color: secondaryText),
      labelLarge: TextStyle(
          fontFamily: brand.bodyFontFamily,
          fontFamilyFallback: brand.bodyFontFallback,
          fontSize: 14,
          height: 1.2,
          letterSpacing: 0,
          fontWeight: FontWeight.w700,
          color: onSurface),
      // Data/mono role (Handoff §1): numeric metadata, codes, counters.
      labelMedium: semantic.dataLabel,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      fontFamily: brand.bodyFontFamily,
      fontFamilyFallback: brand.bodyFontFallback,
      extensions: [brand, semantic],
      appBarTheme: AppBarTheme(
        elevation: AppElevation.level0,
        centerTitle: false,
        backgroundColor: background,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ComponentThemes.elevatedButtonTheme(scheme),
      filledButtonTheme: ComponentThemes.filledButtonTheme(scheme),
      outlinedButtonTheme: ComponentThemes.outlinedButtonTheme(scheme),
      textButtonTheme: ComponentThemes.textButtonTheme(scheme),
      inputDecorationTheme: ComponentThemes.inputDecorationTheme(scheme),
      cardTheme: ComponentThemes.cardTheme(scheme),
      chipTheme: ComponentThemes.chipTheme(scheme, textTheme),
      segmentedButtonTheme:
          ComponentThemes.segmentedButtonTheme(scheme, textTheme),
      navigationBarTheme: ComponentThemes.navigationBarTheme(scheme, textTheme),
      navigationRailTheme:
          ComponentThemes.navigationRailTheme(scheme, textTheme),
      listTileTheme: ComponentThemes.listTileTheme(scheme),
      dividerTheme: ComponentThemes.dividerTheme(scheme),
      dialogTheme: ComponentThemes.dialogTheme(scheme),
      bottomSheetTheme: ComponentThemes.bottomSheetTheme(scheme),
      snackBarTheme: ComponentThemes.snackBarTheme(scheme),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Renders [child] with the brand's dark theme whatever the ambient
/// [ThemeMode] is. Camera flow, login and paywall are dark in both themes.
class ForcedDarkTheme extends StatelessWidget {
  const ForcedDarkTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
        data: AppThemeV2.forcedDark(Theme.of(context)),
        child: child,
      );
}
