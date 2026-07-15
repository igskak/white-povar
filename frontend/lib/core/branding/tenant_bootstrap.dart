import 'brand_config.dart';

class TenantBootstrap {
  const TenantBootstrap({
    required this.tenantSlug,
    required this.brandConfig,
    required this.configVersion,
  });

  final String tenantSlug;
  final BrandConfig brandConfig;
  final String configVersion;

  factory TenantBootstrap.fromJson(Map<String, dynamic> json) {
    final tenant = _requiredMap(json, 'tenant');
    final tenantSlug = _requiredString(tenant, 'slug');
    final config = BrandConfig.fromJson(_requiredMap(json, 'brandConfig'));
    if (config.tenantSlug != tenantSlug) {
      throw const FormatException(
          'Bootstrap tenant and BrandConfig do not match.');
    }
    return TenantBootstrap(
      tenantSlug: tenantSlug,
      brandConfig: config,
      configVersion: _requiredString(json, 'configVersion'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid TenantBootstrap $key.');
  }
  return value;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('Missing or invalid TenantBootstrap $key.');
  }
  return value;
}
