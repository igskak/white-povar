import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'component_themes.dart';
import 'tokens/app_tokens.dart';

class AppThemeV2 {
  static const _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFD9A441),
    onPrimary: Color(0xFF16130F),
    secondary: Color(0xFFC9A24B),
    onSecondary: Color(0xFF16130F),
    error: Color(0xFFD67A6B),
    onError: Color(0xFF16130F),
    surface: Color(0xFF221D16),
    onSurface: Color(0xFFF3E9DA),
  );

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
        letterSpacing: 0,
        color: AppColorsV2.textPrimary,
      ),
      headlineMedium: const TextStyle(
        fontSize: 30,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
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
        letterSpacing: 0,
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

  static ThemeData dark() {
    final textTheme = Typography.whiteMountainView.copyWith(
      headlineLarge: const TextStyle(
        fontSize: 40,
        height: 1.05,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: Color(0xFFF3E9DA),
      ),
      headlineMedium: const TextStyle(
        fontSize: 30,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: Color(0xFFF3E9DA),
      ),
      titleLarge: const TextStyle(
        fontSize: 22,
        height: 1.15,
        fontWeight: FontWeight.w600,
        color: Color(0xFFF3E9DA),
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        height: 1.4,
        color: Color(0xFFF3E9DA),
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        height: 1.4,
        color: Color(0xFFF3E9DA),
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        height: 1.3,
        color: Color(0xFFB9AC98),
      ),
      labelSmall: const TextStyle(
        fontSize: 11,
        letterSpacing: 0,
        color: Color(0xFFB9AC98),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkColorScheme,
      scaffoldBackgroundColor: const Color(0xFF16130F),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        elevation: AppElevation.level0,
        centerTitle: false,
        backgroundColor: Color(0xFF16130F),
        foregroundColor: Color(0xFFF3E9DA),
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 72,
        backgroundColor: Color(0xFF221D16),
        indicatorColor: Color(0xFF2E2820),
        elevation: 0,
      ),
      elevatedButtonTheme:
          ComponentThemes.elevatedButtonTheme(_darkColorScheme),
      inputDecorationTheme:
          ComponentThemes.inputDecorationTheme(_darkColorScheme),
      cardTheme: ComponentThemes.cardTheme(_darkColorScheme),
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

final appThemeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
