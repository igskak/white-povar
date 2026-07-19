import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/router/app_router.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/app/theme/theme_mode_controller.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/core/branding/brand_providers.dart';
import 'package:frontend/core/branding/tenant_bootstrap.dart';
import 'package:frontend/core/services/analytics_service.dart';
import 'package:frontend/features/profile/presentation/pages/settings_page.dart';

void main() {
  testWidgets('Settings goldens at handoff breakpoints', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final width in [390.0, 768.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(_settingsApp('settings-$width'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await expectLater(
        find.byType(AdaptiveNavigationShell),
        matchesGoldenFile('goldens/settings_${width.toInt()}.png'),
      );
      expect(tester.takeException(), isNull, reason: 'width: $width');
    }
  }, tags: 'golden');
}

Widget _settingsApp(String fixtureKey) => ProviderScope(
      key: ValueKey(fixtureKey),
      overrides: [
        tenantBootstrapProvider.overrideWithValue(_bootstrap),
        appThemeModeProvider.overrideWith(
          (_) => ThemeModeController(_MemoryThemeModeStorage()),
        ),
        analyticsServiceProvider.overrideWithValue(_FakeAnalyticsService()),
      ],
      child: MaterialApp(
        theme: AppThemeV2.light(_brand),
        home: const AdaptiveNavigationShell(
          selectedIndex: 3,
          onDestinationSelected: _ignoreDestination,
          child: SettingsPage(embeddedInDesktopShell: true),
        ),
      ),
    );

void _ignoreDestination(int _) {}

class _MemoryThemeModeStorage implements ThemeModeStorage {
  @override
  Future<String?> read() async => 'system';

  @override
  Future<void> write(String value) async {}
}

class _FakeAnalyticsService extends AnalyticsService {
  _FakeAnalyticsService()
      : super(ApiClient(
          baseUrl: 'https://example.invalid',
          tokenProvider: () async => null,
          tenantSlug: 'ohorodnik-oleksandr',
          locale: 'uk',
        ));

  @override
  Future<bool> consent() async => false;

  @override
  Future<void> setConsent(bool enabled) async {}
}

const _brand = BrandConfig(
  schemaVersion: 1,
  tenantSlug: 'ohorodnik-oleksandr',
  locale: 'uk',
  brand: BrandDetails(
    name: 'Огороднік Олександр',
    creatorName: 'Олександр',
    avatar: 'PENDING:/avatar.png',
    accent: '#5D7183',
    font: 'grotesque',
    voice: BrandVoice(
      greeting: 'Ой, друзі',
      loginTitle: 'Готуйте з Олександром',
      paywallTitle: 'Колекції Олександра',
      courseName: 'Майстерня Олександра',
    ),
    derived: DerivedBrandColors(
      accentPressed: '#4B5E70',
      accentOnDark: '#6B8092',
      onAccent: '#FFFFFF',
      lightCtaMode: 'accentFill',
    ),
    heroPhotos: [],
    courseTag: 'maisternia-oleksandra',
  ),
);

const _bootstrap = TenantBootstrap(
  tenantSlug: 'ohorodnik-oleksandr',
  brandConfig: _brand,
  configVersion: 'settings-golden',
);
