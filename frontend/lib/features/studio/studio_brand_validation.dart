/// A client-side mirror of the 13a schema limits and the 13b contrast gates.
///
/// This is deliberately **not authoritative**. The server re-validates every
/// field and recomputes the derived colours when the draft is published; these
/// checks exist only so the editor can show the outcome — a green section, a
/// blocked publish button, the CTA the light theme will actually get — without
/// a round trip. Where the two ever disagree, the server wins.
library;

import 'dart:math' as math;

/// 13a character limits.
const int kBrandNameLimit = 20;
const int kCreatorNameLimit = 16;
const int kGreetingLimit = 24;
const int kLoginTitleLimit = 28;
const int kPaywallTitleLimit = 28;
const int kCourseNameLimit = 36;

/// 13d hero frame count.
const int kMinHeroPhotos = 3;
const int kMaxHeroPhotos = 6;

/// Scene colours the gates are measured against (Handoff §1).
const String kLightBackground = '#F5EEE1';
const String kInk = '#16130F';

enum StudioSectionStatus {
  /// Every required field in the section is present and within its limit.
  ok,

  /// Publishable, but the tenant will fall back to a default (13j).
  warning,

  /// Publishing is blocked until this is fixed.
  invalid,
}

/// Per-section validity for the four Creator Studio accordions (13m).
class StudioBrandChecks {
  const StudioBrandChecks({
    required this.identity,
    required this.colour,
    required this.voice,
    required this.photos,
  });

  final StudioSectionStatus identity;
  final StudioSectionStatus colour;
  final StudioSectionStatus voice;
  final StudioSectionStatus photos;

  /// 13m: «кнопка публікації активна лише коли всі обов'язкові секції зелені».
  /// heroPhotos are optional, so a warning there does not block a publish.
  bool get canPublish =>
      identity == StudioSectionStatus.ok &&
      colour == StudioSectionStatus.ok &&
      voice == StudioSectionStatus.ok &&
      photos != StudioSectionStatus.invalid;

  factory StudioBrandChecks.of({
    required String name,
    required String creatorName,
    required String? avatar,
    required String accent,
    required String greeting,
    required String loginTitle,
    required String paywallTitle,
    required String courseName,
    required String courseTag,
    required int photoCount,
  }) {
    bool within(String value, int limit) {
      final trimmed = value.trim();
      return trimmed.isNotEmpty && trimmed.length <= limit;
    }

    // courseName and courseTag are optional but must arrive together (13g).
    final course = courseName.trim(), tag = courseTag.trim();
    final courseValid = (course.isEmpty && tag.isEmpty) ||
        (course.isNotEmpty &&
            tag.isNotEmpty &&
            course.length <= kCourseNameLimit);

    return StudioBrandChecks(
      identity: within(name, kBrandNameLimit) &&
              within(creatorName, kCreatorNameLimit) &&
              (avatar ?? '').trim().isNotEmpty
          ? StudioSectionStatus.ok
          : StudioSectionStatus.invalid,
      colour: isBrandHex(accent)
          ? StudioSectionStatus.ok
          : StudioSectionStatus.invalid,
      voice: within(greeting, kGreetingLimit) &&
              within(loginTitle, kLoginTitleLimit) &&
              within(paywallTitle, kPaywallTitleLimit) &&
              courseValid
          ? StudioSectionStatus.ok
          : StudioSectionStatus.invalid,
      photos: photoCount > kMaxHeroPhotos
          ? StudioSectionStatus.invalid
          : photoCount == 0 || photoCount >= kMinHeroPhotos
              // Zero frames is a supported choice: the app uses the gradient.
              ? StudioSectionStatus.ok
              : StudioSectionStatus.warning,
    );
  }
}

bool isBrandHex(String value) =>
    RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value.trim());

/// The 13b gate outcome for one accent, previewed client-side.
class BrandContrast {
  const BrandContrast({
    required this.onLightBackground,
    required this.onInk,
  });

  /// contrast(accent, #F5EEE1) — decides whether the light CTA may be a fill.
  final double onLightBackground;

  /// contrast(accent, #16130F) — the dark-scene legibility of the raw accent.
  final double onInk;

  /// WCAG 1.4.11 non-text contrast: below 3.0 the accent cannot carry the CTA
  /// fill, so the light theme falls back to an ink fill with an accent icon.
  bool get accentFillAllowed => onLightBackground >= 3;

  /// 13b: onAccent is ink when ink reads on the accent, otherwise white.
  bool get onAccentIsInk => onInk >= 4.5;

  static BrandContrast? of(String accent) {
    if (!isBrandHex(accent)) return null;
    return BrandContrast(
      onLightBackground: contrastRatio(accent, kLightBackground)!,
      onInk: contrastRatio(accent, kInk)!,
    );
  }
}

/// WCAG 2.1 contrast ratio between two `#RRGGBB` colours, or null if either
/// is not a valid brand hex.
double? contrastRatio(String a, String b) {
  final first = _luminance(a), second = _luminance(b);
  if (first == null || second == null) return null;
  final lighter = math.max(first, second), darker = math.min(first, second);
  return (lighter + .05) / (darker + .05);
}

/// Relative luminance per WCAG 2.1. Parsed straight from the hex string so the
/// gate never depends on how a `Color` happens to expose its channels.
double? _luminance(String hex) {
  if (!isBrandHex(hex)) return null;
  final value = int.parse(hex.trim().substring(1), radix: 16);
  double channel(int shift) {
    final srgb = ((value >> shift) & 0xFF) / 255;
    return srgb <= .03928
        ? srgb / 12.92
        : math.pow((srgb + .055) / 1.055, 2.4).toDouble();
  }

  return .2126 * channel(16) + .7152 * channel(8) + .0722 * channel(0);
}
