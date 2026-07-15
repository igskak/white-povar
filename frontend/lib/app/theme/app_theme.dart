import 'package:flutter/material.dart';

import '../../core/branding/brand_config.dart';
import 'brand_theme.dart';
import 'component_themes.dart';
import 'tokens/app_tokens.dart';

class AppThemeV2 {
  static ThemeData light(BrandConfig brandConfig) => _build(
        brandConfig: brandConfig,
        brightness: Brightness.light,
      );

  static ThemeData dark(BrandConfig brandConfig) => _build(
        brandConfig: brandConfig,
        brightness: Brightness.dark,
      );

  static ThemeData _build({
    required BrandConfig brandConfig,
    required Brightness brightness,
  }) {
    final brand = BrandThemeExtension.fromConfig(brandConfig);
    final isDark = brightness == Brightness.dark;
    final background = isDark ? AppColorsV2.ink : AppColorsV2.bg;
    final surface = isDark ? const Color(0xFF221D16) : AppColorsV2.surface;
    final onSurface = isDark ? AppColorsV2.onInk : AppColorsV2.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB9AC98) : AppColorsV2.textSecondary;
    final primary = isDark ? brand.accentOnDark : brand.accent;
    final lightPrimary =
        brand.lightCtaMode == 'accentFill' ? primary : AppColorsV2.ink;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: lightPrimary,
      onPrimary: brand.lightCtaMode == 'accentFill'
          ? brand.onAccent
          : AppColorsV2.onInk,
      secondary: AppColorsV2.premiumGold,
      onSecondary: AppColorsV2.ink,
      error: AppColorsV2.error,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
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
      titleLarge: TextStyle(
          fontFamily: brand.displayFontFamily,
          fontSize: 22,
          height: 1.15,
          fontWeight: FontWeight.w600,
          color: onSurface),
      bodyLarge: TextStyle(
          fontFamily: brand.bodyFontFamily,
          fontSize: 16,
          height: 1.4,
          color: onSurface),
      bodyMedium: TextStyle(
          fontFamily: brand.bodyFontFamily,
          fontSize: 14,
          height: 1.4,
          color: onSurface),
      bodySmall: TextStyle(
          fontFamily: brand.bodyFontFamily,
          fontSize: 12,
          height: 1.3,
          color: secondaryText),
      labelSmall: TextStyle(
          fontFamily: brand.bodyFontFamily,
          fontSize: 11,
          letterSpacing: 0,
          color: secondaryText),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      fontFamily: brand.bodyFontFamily,
      extensions: [brand],
      appBarTheme: AppBarTheme(
        elevation: AppElevation.level0,
        centerTitle: false,
        backgroundColor: background,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: surface,
        indicatorColor:
            isDark ? const Color(0xFF2E2820) : AppColorsV2.surfaceStrong,
        elevation: 0,
      ),
      elevatedButtonTheme: ComponentThemes.elevatedButtonTheme(scheme),
      inputDecorationTheme: ComponentThemes.inputDecorationTheme(scheme),
      cardTheme: ComponentThemes.cardTheme(scheme),
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
