import 'dart:convert';

/// A deliberately strict representation of the published brand contract.
/// Invalid runtime configuration must fail parsing rather than silently becoming
/// a generic White Povar experience.
class BrandConfig {
  const BrandConfig({
    required this.schemaVersion,
    required this.tenantSlug,
    required this.locale,
    required this.brand,
  });

  final int schemaVersion;
  final String tenantSlug;
  final String locale;
  final BrandDetails brand;

  factory BrandConfig.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schemaVersion');
    if (schemaVersion != 1) {
      throw const FormatException('Unsupported BrandConfig schemaVersion.');
    }
    final tenantSlug = _requiredString(json, 'tenantSlug');
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(tenantSlug)) {
      throw const FormatException('Invalid BrandConfig tenantSlug.');
    }
    final locale = _requiredString(json, 'locale');
    if (locale != 'uk') {
      throw const FormatException('Unsupported BrandConfig locale.');
    }

    return BrandConfig(
      schemaVersion: schemaVersion,
      tenantSlug: tenantSlug,
      locale: locale,
      brand: BrandDetails.fromJson(_requiredMap(json, 'brand')),
    );
  }
}

class BrandDetails {
  const BrandDetails({
    required this.name,
    required this.creatorName,
    required this.avatar,
    required this.accent,
    required this.font,
    required this.voice,
    required this.derived,
  });

  final String name;
  final String creatorName;
  final String avatar;
  final String accent;
  final String font;
  final BrandVoice voice;
  final DerivedBrandColors derived;

  factory BrandDetails.fromJson(Map<String, dynamic> json) {
    final accent = _requiredString(json, 'accent');
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(accent)) {
      throw const FormatException('Invalid BrandConfig accent.');
    }
    final font = _requiredString(json, 'font');
    if (!const {'serif', 'grotesque', 'humanist'}.contains(font)) {
      throw const FormatException('Invalid BrandConfig font.');
    }
    return BrandDetails(
      name: _requiredString(json, 'name'),
      creatorName: _requiredString(json, 'creatorName'),
      avatar: _requiredString(json, 'avatar'),
      accent: accent.toUpperCase(),
      font: font,
      voice: BrandVoice.fromJson(_requiredMap(json, 'voice')),
      derived: DerivedBrandColors.fromJson(_requiredMap(json, 'derived')),
    );
  }
}

class BrandVoice {
  const BrandVoice({
    required this.greeting,
    required this.loginTitle,
    required this.paywallTitle,
  });

  final String greeting;
  final String loginTitle;
  final String paywallTitle;

  factory BrandVoice.fromJson(Map<String, dynamic> json) => BrandVoice(
        greeting: _requiredString(json, 'greeting'),
        loginTitle: _requiredString(json, 'loginTitle'),
        paywallTitle: _requiredString(json, 'paywallTitle'),
      );
}

class DerivedBrandColors {
  const DerivedBrandColors({
    required this.accentPressed,
    required this.accentOnDark,
    required this.onAccent,
    required this.lightCtaMode,
  });

  final String accentPressed;
  final String accentOnDark;
  final String onAccent;
  final String lightCtaMode;

  factory DerivedBrandColors.fromJson(Map<String, dynamic> json) {
    final onAccent = _requiredString(json, 'onAccent');
    final lightCtaMode = _requiredString(json, 'lightCtaMode');
    if (!const {'#16130F', '#FFFFFF'}.contains(onAccent) ||
        !const {'accentFill', 'inkFill'}.contains(lightCtaMode)) {
      throw const FormatException('Invalid BrandConfig derived colours.');
    }
    return DerivedBrandColors(
      accentPressed: _hex(json, 'accentPressed'),
      accentOnDark: _hex(json, 'accentOnDark'),
      onAccent: onAccent,
      lightCtaMode: lightCtaMode,
    );
  }
}

Map<String, dynamic> decodeJsonObject(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) return decoded;
  } on FormatException {
    // Normalise JSON parser details to the public bootstrap failure contract.
  }
  throw const FormatException('Expected a JSON object.');
}

String _hex(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
    throw FormatException('Invalid BrandConfig $key.');
  }
  return value.toUpperCase();
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid BrandConfig $key.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Missing or invalid BrandConfig $key.');
  }
  return value;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('Missing or invalid BrandConfig $key.');
  }
  return value;
}
