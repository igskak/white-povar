import 'package:flutter/material.dart';

import 'tokens/app_tokens.dart';

class ComponentThemes {
  static ElevatedButtonThemeData elevatedButtonTheme(ColorScheme scheme) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: AppElevation.level1,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
    );
  }

  static InputDecorationTheme inputDecorationTheme(ColorScheme scheme) {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColorsV2.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      border: const OutlineInputBorder(borderRadius: AppRadius.md),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: BorderSide(color: scheme.error),
      ),
    );
  }

  static CardTheme cardTheme(ColorScheme scheme) {
    return CardTheme(
      color: scheme.surface,
      elevation: AppElevation.level1,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
      margin: const EdgeInsets.all(AppSpacing.xs),
    );
  }
}
