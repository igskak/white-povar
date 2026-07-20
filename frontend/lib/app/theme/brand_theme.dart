import 'package:flutter/material.dart';

import '../../core/branding/brand_config.dart';
import 'tokens/app_tokens.dart';

/// Brand-owned presentation values. System semantic colours stay in AppColorsV2.
class BrandThemeExtension extends ThemeExtension<BrandThemeExtension> {
  const BrandThemeExtension({
    required this.accent,
    required this.accentPressed,
    required this.accentOnDark,
    required this.onAccent,
    required this.lightCtaMode,
    required this.displayFontFamily,
    required this.bodyFontFamily,
    this.bodyFontFallback = AppFonts.bodyFallback,
  });

  final Color accent;
  final Color accentPressed;
  final Color accentOnDark;
  final Color onAccent;
  final String lightCtaMode;
  final String displayFontFamily;
  final String bodyFontFamily;

  /// Appended after [bodyFontFamily] so Cyrillic body glyphs always resolve
  /// (design 13c UI stack: 'Figtree', 'Golos Text', sans-serif).
  final List<String> bodyFontFallback;

  factory BrandThemeExtension.fromConfig(BrandConfig config) {
    // Curated display pairings (design 13c). The UI/body family is shared.
    final displayFontFamily = switch (config.brand.font) {
      'serif' => 'Source Serif 4',
      'grotesque' => 'Golos Text',
      'humanist' => 'Lora',
      _ => 'Source Serif 4',
    };
    return BrandThemeExtension(
      accent: _color(config.brand.accent),
      accentPressed: _color(config.brand.derived.accentPressed),
      accentOnDark: _color(config.brand.derived.accentOnDark),
      onAccent: _color(config.brand.derived.onAccent),
      lightCtaMode: config.brand.derived.lightCtaMode,
      displayFontFamily: displayFontFamily,
      bodyFontFamily: AppFonts.body,
    );
  }

  static Color _color(String hex) =>
      Color(int.parse('FF${hex.substring(1)}', radix: 16));

  @override
  BrandThemeExtension copyWith({
    Color? accent,
    Color? accentPressed,
    Color? accentOnDark,
    Color? onAccent,
    String? lightCtaMode,
    String? displayFontFamily,
    String? bodyFontFamily,
    List<String>? bodyFontFallback,
  }) =>
      BrandThemeExtension(
        accent: accent ?? this.accent,
        accentPressed: accentPressed ?? this.accentPressed,
        accentOnDark: accentOnDark ?? this.accentOnDark,
        onAccent: onAccent ?? this.onAccent,
        lightCtaMode: lightCtaMode ?? this.lightCtaMode,
        displayFontFamily: displayFontFamily ?? this.displayFontFamily,
        bodyFontFamily: bodyFontFamily ?? this.bodyFontFamily,
        bodyFontFallback: bodyFontFallback ?? this.bodyFontFallback,
      );

  @override
  BrandThemeExtension lerp(
      ThemeExtension<BrandThemeExtension>? other, double t) {
    if (other is! BrandThemeExtension) return this;
    return BrandThemeExtension(
      accent: Color.lerp(accent, other.accent, t)!,
      accentPressed: Color.lerp(accentPressed, other.accentPressed, t)!,
      accentOnDark: Color.lerp(accentOnDark, other.accentOnDark, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      lightCtaMode: t < .5 ? lightCtaMode : other.lightCtaMode,
      displayFontFamily: t < .5 ? displayFontFamily : other.displayFontFamily,
      bodyFontFamily: t < .5 ? bodyFontFamily : other.bodyFontFamily,
      bodyFontFallback: t < .5 ? bodyFontFallback : other.bodyFontFallback,
    );
  }
}

extension BrandThemeContext on BuildContext {
  BrandThemeExtension get brandTheme =>
      Theme.of(this).extension<BrandThemeExtension>()!;
}
