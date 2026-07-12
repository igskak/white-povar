import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'component_themes.dart';
import 'tokens/app_tokens.dart';

class AppThemeV2 {
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColorsV2.accent,
      onPrimary: Colors.white,
      secondary: AppColorsV2.warning,
      onSecondary: Colors.white,
      error: AppColorsV2.error,
      onError: Colors.white,
      surface: AppColorsV2.surface,
      onSurface: AppColorsV2.textPrimary,
    );

    final textTheme = Typography.blackMountainView.copyWith(
      headlineLarge: const TextStyle(
        fontSize: 40,
        height: 1.05,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        color: AppColorsV2.textPrimary,
      ),
      headlineMedium: const TextStyle(
        fontSize: 30,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
        color: AppColorsV2.textPrimary,
      ),
      titleLarge: const TextStyle(
        fontSize: 22,
        height: 1.15,
        fontWeight: FontWeight.w600,
        color: AppColorsV2.textPrimary,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        height: 1.4,
        color: AppColorsV2.textPrimary,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        height: 1.4,
        color: AppColorsV2.textPrimary,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        height: 1.3,
        color: AppColorsV2.textSecondary,
      ),
      labelSmall: const TextStyle(
        fontSize: 11,
        letterSpacing: 0.2,
        color: AppColorsV2.textSecondary,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColorsV2.bg,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        elevation: AppElevation.level0,
        centerTitle: false,
        backgroundColor: AppColorsV2.bg,
        foregroundColor: AppColorsV2.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 72,
        backgroundColor: AppColorsV2.surface,
        indicatorColor: AppColorsV2.surfaceStrong,
        elevation: 0,
      ),
      elevatedButtonTheme: ComponentThemes.elevatedButtonTheme(colorScheme),
      inputDecorationTheme: ComponentThemes.inputDecorationTheme(colorScheme),
      cardTheme: ComponentThemes.cardTheme(colorScheme),
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

final appThemeV2Provider = Provider<ThemeData>((ref) {
  return AppThemeV2.light();
});
