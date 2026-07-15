/// Product-owned links and labels that are intentionally independent from
/// [BrandConfig]. Real endpoints are supplied before the pilot release.
class ProductConfig {
  const ProductConfig({
    required this.appName,
    required this.versionLabel,
    this.supportEmail,
    this.privacyUrl,
    this.termsUrl,
  });

  final String appName;
  final String versionLabel;
  final String? supportEmail;
  final String? privacyUrl;
  final String? termsUrl;

  static const pilot = ProductConfig(
    appName: 'White Povar',
    versionLabel: 'v1.0.0',
  );
}
