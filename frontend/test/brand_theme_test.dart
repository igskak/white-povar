import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/app/theme/brand_theme.dart';
import 'package:frontend/app/theme/theme_mode_controller.dart';
import 'package:frontend/core/branding/brand_assets.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/features/profile/presentation/pages/settings_page.dart';

void main() {
  test(
      'uses validated derived colours and selected bundled font for each brand',
      () {
    for (final config in [
      _config('#5D7183', 'grotesque'),
      _config('#9C4E31', 'serif'),
      _config('#39736D', 'humanist')
    ]) {
      final light = AppThemeV2.light(config);
      final dark = AppThemeV2.dark(config);
      final brand = light.extension<BrandThemeExtension>()!;

      expect(light.colorScheme.primary, brand.accent);
      expect(dark.colorScheme.primary, brand.accentOnDark);
      expect(light.colorScheme.secondary, const Color(0xFFD9A441));
      expect(light.colorScheme.error, const Color(0xFFA8362A));
      expect(light.textTheme.bodyMedium?.fontFamily, brand.bodyFontFamily);
    }
  });

  test('restores and persists system, light and dark theme choices', () async {
    final storage = _MemoryThemeStorage('dark');
    final controller = ThemeModeController(storage);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, ThemeMode.dark);

    await controller.setMode(ThemeMode.light);
    expect(controller.state, ThemeMode.light);
    expect(storage.value, 'light');
  });

  testWidgets('theme choice remains usable at 200 percent text scale',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appThemeModeProvider.overrideWith(
          (ref) => ThemeModeController(_MemoryThemeStorage(null)),
        ),
      ],
      child: MaterialApp(
        theme: AppThemeV2.light(_config('#5D7183', 'grotesque')),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SettingsPage(),
        ),
      ),
    ));

    expect(find.text('Система'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending and missing brand assets use visual fallbacks',
      (tester) async {
    final config = _config('#5D7183', 'grotesque');
    await tester.pumpWidget(MaterialApp(
      theme: AppThemeV2.light(config),
      home: Scaffold(
        body: Column(
          children: [
            BrandAvatar(brand: config.brand),
            BrandLogo(brand: config.brand),
            BrandHero(brand: config.brand, role: 'home'),
          ],
        ),
      ),
    ));

    expect(find.text('Reference'), findsOneWidget);
    expect(find.text('Ref'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

BrandConfig _config(String accent, String font) => BrandConfig.fromJson({
      'schemaVersion': 1,
      'tenantSlug': 'reference-$font',
      'locale': 'uk',
      'brand': {
        'name': 'Reference',
        'creatorName': 'Ref',
        'avatar': 'PENDING:/avatar.png',
        'accent': accent,
        'font': font,
        'voice': {
          'greeting': 'Hi',
          'loginTitle': 'Login',
          'paywallTitle': 'Paywall'
        },
        'derived': {
          'accentPressed': '#4B5E70',
          'accentOnDark': '#6B8092',
          'onAccent': '#FFFFFF',
          'lightCtaMode': 'accentFill'
        },
      },
    });

class _MemoryThemeStorage implements ThemeModeStorage {
  _MemoryThemeStorage(this.value);
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
