import 'package:flutter/material.dart';

import '../../core/branding/brand_config.dart';

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
  });

  final Color accent;
  final Color accentPressed;
  final Color accentOnDark;
  final Color onAccent;
  final String lightCtaMode;
  final String displayFontFamily;
  final String bodyFontFamily;

  factory BrandThemeExtension.fromConfig(BrandConfig config) {
    final fontFamilies = switch (config.brand.font) {
      'serif' => ('Lora', 'Source Serif 4'),
      'humanist' => ('Golos Text', 'Golos Text'),
      _ => ('Figtree', 'Figtree'),
    };
    return BrandThemeExtension(
      accent: _color(config.brand.accent),
      accentPressed: _color(config.brand.derived.accentPressed),
      accentOnDark: _color(config.brand.derived.accentOnDark),
      onAccent: _color(config.brand.derived.onAccent),
      lightCtaMode: config.brand.derived.lightCtaMode,
      displayFontFamily: fontFamilies.$1,
      bodyFontFamily: fontFamilies.$2,
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
  }) =>
      BrandThemeExtension(
        accent: accent ?? this.accent,
        accentPressed: accentPressed ?? this.accentPressed,
        accentOnDark: accentOnDark ?? this.accentOnDark,
        onAccent: onAccent ?? this.onAccent,
        lightCtaMode: lightCtaMode ?? this.lightCtaMode,
        displayFontFamily: displayFontFamily ?? this.displayFontFamily,
        bodyFontFamily: bodyFontFamily ?? this.bodyFontFamily,
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
    );
  }
}

extension BrandThemeContext on BuildContext {
  BrandThemeExtension get brandTheme =>
      Theme.of(this).extension<BrandThemeExtension>()!;
}
