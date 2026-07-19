import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/core/branding/brand_providers.dart';
import 'package:frontend/core/branding/tenant_bootstrap.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/subscription/paywall_provider.dart';
import 'package:frontend/features/subscription/purchase_adapter.dart';
import 'package:frontend/features/subscription/screens/subscription_screen.dart';

void main() {
  testWidgets('Paywall state goldens at handoff breakpoints', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final state in _PaywallFixtureState.values) {
      for (final width in [390.0, 768.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(
          _paywallApp(state, fixtureKey: '${state.name}-$width'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await expectLater(
          find.byType(SubscriptionScreen),
          matchesGoldenFile(
            'goldens/paywall_${state.name}_${width.toInt()}.png',
          ),
        );
        expect(tester.takeException(), isNull,
            reason: '${state.name} at $width');
      }
    }
  }, tags: 'golden');
}

Widget _paywallApp(
  _PaywallFixtureState state, {
  required String fixtureKey,
}) =>
    ProviderScope(
      key: ValueKey(fixtureKey),
      overrides: [
        tenantBootstrapProvider.overrideWithValue(_bootstrap),
        purchaseAdapterProvider.overrideWithValue(
          FakePurchaseAdapter(snapshot: _snapshot(state)),
        ),
        authProvider.overrideWith((_) => AuthNotifier.testing()),
      ],
      child: MaterialApp(
        theme: AppThemeV2.light(_brand),
        darkTheme: AppThemeV2.dark(_brand),
        home: const SubscriptionScreen(),
      ),
    );

enum _PaywallFixtureState { catalogue, active, error }

PaywallSnapshot _snapshot(_PaywallFixtureState state) => switch (state) {
      _PaywallFixtureState.catalogue => const PaywallSnapshot(
          phase: PaywallPhase.idle,
          products: _products,
        ),
      _PaywallFixtureState.active => PaywallSnapshot(
          phase: PaywallPhase.active,
          renewsOn: DateTime(2027, 7, 19),
        ),
      _PaywallFixtureState.error => const PaywallSnapshot(
          phase: PaywallPhase.error,
          products: _products,
          message: 'Не вдалося завершити операцію. Спробуйте ще раз.',
        ),
    };

const _products = [
  PurchaseProduct(
    id: 'premium.annual',
    title: 'Річний доступ',
    price: '1 499 ₴',
    detail: '125 ₴/міс після пробного періоду',
    trial: '7 днів безкоштовно',
    badge: 'Найвигідніше',
  ),
  PurchaseProduct(
    id: 'premium.monthly',
    title: 'Місячний доступ',
    price: '199 ₴',
    detail: 'Оплата щомісяця',
  ),
];

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
  configVersion: 'paywall-golden',
);
