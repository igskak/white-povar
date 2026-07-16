import 'app_config.dart';

/// Product-owned public labels and notices, independent from [BrandConfig].
class ProductConfig {
  const ProductConfig({
    required this.appName,
    required this.versionLabel,
    this.supportEmail,
    required this.demoPrivacyNotice,
    required this.demoUseNotice,
  });

  final String appName;
  final String versionLabel;
  final String? supportEmail;
  final String demoPrivacyNotice;
  final String demoUseNotice;

  static const pilot = ProductConfig(
    appName: 'Огороднік Олександр',
    versionLabel: AppConfig.buildLabel,
    supportEmail: AppConfig.supportEmail,
    demoPrivacyNotice:
        'У демо-версії ми обробляємо дані акаунта лише для роботи сервісу. Не додавайте чутливі дані до публічних полів.',
    demoUseNotice:
        'Демо-доступ не є оплатою: кошти не списуються, а доступ може бути відкликаний для завершення пілоту.',
  );
}
