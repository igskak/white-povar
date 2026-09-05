import 'package:flutter/material.dart';

import 'tokens/app_tokens.dart';

class ComponentThemes {
  static ElevatedButtonThemeData elevatedButtonTheme(ColorScheme scheme) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: AppElevation.level1,
          shadowColor: scheme.shadow.withOpacity(.22),
          minimumSize: const Size(44, 46),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );

  static FilledButtonThemeData filledButtonTheme(ColorScheme scheme) =>
      FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 46),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );

  static OutlinedButtonThemeData outlinedButtonTheme(ColorScheme scheme) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 46),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          foregroundColor: scheme.secondary,
          side: BorderSide(color: scheme.outline),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );

  static TextButtonThemeData textButtonTheme(ColorScheme scheme) =>
      TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: scheme.secondary,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );

  static InputDecorationTheme inputDecorationTheme(ColorScheme scheme) =>
      InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: const OutlineInputBorder(borderRadius: AppRadius.md),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: scheme.secondary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      );

  static CardTheme cardTheme(ColorScheme scheme) => CardTheme(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.shadow.withOpacity(.18),
        elevation: AppElevation.level0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lg,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      );

  static ChipThemeData chipTheme(ColorScheme scheme, TextTheme textTheme) =>
      ChipThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        selectedColor: scheme.primaryContainer,
        secondarySelectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerHigh.withOpacity(.6),
        deleteIconColor: scheme.onSurfaceVariant,
        checkmarkColor: scheme.onPrimaryContainer,
        showCheckmark: false,
        surfaceTintColor: Colors.transparent,
        side: BorderSide(color: scheme.outlineVariant),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        labelStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      );

  static SegmentedButtonThemeData segmentedButtonTheme(
    ColorScheme scheme,
    TextTheme textTheme,
  ) =>
      SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(44, 42)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.md),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerLowest),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? scheme.onPrimaryContainer
                  : scheme.onSurface),
          textStyle: WidgetStatePropertyAll(
            textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      );

  static NavigationBarThemeData navigationBarTheme(
    ColorScheme scheme,
    TextTheme textTheme,
  ) =>
      NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? scheme.secondary
                  : scheme.onSurfaceVariant,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => textTheme.labelSmall?.copyWith(
                  color: states.contains(WidgetState.selected)
                      ? scheme.secondary
                      : scheme.onSurfaceVariant,
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w700
                      : FontWeight.w500,
                )),
      );

  static NavigationRailThemeData navigationRailTheme(
    ColorScheme scheme,
    TextTheme textTheme,
  ) =>
      NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.secondary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: scheme.secondary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      );

  static ListTileThemeData listTileTheme(ColorScheme scheme) =>
      ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        selectedColor: scheme.secondary,
        selectedTileColor: scheme.primaryContainer,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      );

  static DividerThemeData dividerTheme(ColorScheme scheme) => DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      );

  static DialogTheme dialogTheme(ColorScheme scheme) => DialogTheme(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.shadow.withOpacity(.24),
        elevation: AppElevation.level3,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
      );

  static BottomSheetThemeData bottomSheetTheme(ColorScheme scheme) =>
      BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        modalBackgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      );

  static SnackBarThemeData snackBarTheme(ColorScheme scheme) =>
      SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      );
}
