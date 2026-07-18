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
import 'package:frontend/features/subscription/providers/subscription_provider.dart';
import 'package:frontend/features/subscription/screens/subscription_screen.dart';
import 'package:frontend/core/widgets/design_system.dart';

void main() {
  test('server-entitled paywall state unlocks shared premium gates', () async {
    final container = ProviderContainer(overrides: [
      purchaseAdapterProvider.overrideWithValue(FakePurchaseAdapter(
        snapshot: const PaywallSnapshot(phase: PaywallPhase.active),
      )),
      authProvider.overrideWith((_) => AuthNotifier.testing()),
    ]);
    addTearDown(container.dispose);

    await container.read(paywallProvider.notifier).load();

    expect(container.read(isPremiumProvider), isTrue);
  });

  for (final scenario in _scenarios) {
    testWidgets('paywall renders ${scenario.phase.name} state', (tester) async {
      await tester.pumpWidget(
        _app(
          FakePurchaseAdapter(
            snapshot: PaywallSnapshot(
              phase: scenario.phase,
              products: scenario.phase == PaywallPhase.productsLoading ||
                      scenario.phase == PaywallPhase.productsUnavailable
                  ? const []
                  : const [_product],
            ),
          ),
        ),
      );
      await tester.pump();

      if (scenario.phase == PaywallPhase.productsLoading) {
        expect(find.byType(AppSkeleton), findsNWidgets(2));
      } else {
        expect(find.text(scenario.expectedText), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a repeated purchase tap results in one adapter purchase',
      (tester) async {
    final adapter = _CountingAdapter();
    await tester.pumpWidget(_app(adapter));
    await tester.pump();

    await tester.tap(find.text('Активувати демо-доступ'));
    await tester.tap(find.text('Активувати демо-доступ'));
    await tester.pump();

    expect(adapter.purchaseCalls, 1);
    expect(find.text('Premium активовано.'), findsOneWidget);
  });

  testWidgets('restore and manage actions are state-specific', (tester) async {
    final active = FakePurchaseAdapter(
      snapshot: const PaywallSnapshot(phase: PaywallPhase.active),
    );
    await tester.pumpWidget(_app(active));
    await tester.pump();
    expect(find.text('Керувати підпискою'), findsOneWidget);
    expect(find.text('Відновити покупку'), findsNothing);
  });

  testWidgets('paywall remains usable at 200% text scale', (tester) async {
    await tester.pumpWidget(
      _app(FakePurchaseAdapter(), textScaler: const TextScaler.linear(2)),
    );
    await tester.pump();
    expect(find.text('Колекції Олександра'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paywall goldens at design breakpoints', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [390.0, 768.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_app(FakePurchaseAdapter()));
      await tester.pump();
      await expectLater(
        find.byType(SubscriptionScreen),
        matchesGoldenFile('goldens/subscription_${width.toInt()}.png'),
      );
    }
  }, tags: 'golden');
}

const _product = PurchaseProduct(
  id: 'test.annual',
  title: 'Річний',
  price: 'test price',
  trial: '7 днів безкоштовно',
);

final _scenarios = <({PaywallPhase phase, String expectedText})>[
  (phase: PaywallPhase.idle, expectedText: 'Колекції Олександра'),
  (phase: PaywallPhase.productsLoading, expectedText: 'Завантаження'),
  (
    phase: PaywallPhase.productsUnavailable,
    expectedText: 'Продукти зараз недоступні.'
  ),
  (
    phase: PaywallPhase.notAllowlisted,
    expectedText: 'Демо-доступ недоступний для цього акаунта.'
  ),
  (phase: PaywallPhase.purchasing, expectedText: 'Premium-колекції та рецепти'),
  (
    phase: PaywallPhase.confirmationPending,
    expectedText: 'Підтверджуємо доступ на сервері…'
  ),
  (phase: PaywallPhase.success, expectedText: 'Premium активовано.'),
  (
    phase: PaywallPhase.error,
    expectedText: 'Покупку не завершено. Кошти не списано.'
  ),
  (
    phase: PaywallPhase.userCancelled,
    expectedText: 'Покупку скасовано. Кошти не списано.'
  ),
  (phase: PaywallPhase.active, expectedText: 'Premium активний'),
  (
    phase: PaywallPhase.grace,
    expectedText: 'Пільговий період активний. Оновіть спосіб оплати.'
  ),
  (
    phase: PaywallPhase.billingRetry,
    expectedText: 'Повторюємо оплату. Premium-доступ поки активний.'
  ),
  (phase: PaywallPhase.expired, expectedText: 'Підписка завершилась.'),
  (phase: PaywallPhase.cancelled, expectedText: 'Автопоновлення вимкнено.'),
]
    .map((entry) => (
          phase: entry.phase,
          expectedText: entry.expectedText,
        ))
    .toList();

Widget _app(PurchaseAdapter adapter, {TextScaler? textScaler}) => ProviderScope(
      overrides: [
        tenantBootstrapProvider.overrideWithValue(_bootstrap),
        purchaseAdapterProvider.overrideWithValue(adapter),
        authProvider.overrideWith((_) => AuthNotifier.testing()),
      ],
      child: MaterialApp(
        theme: AppThemeV2.light(_brandConfig),
        darkTheme: AppThemeV2.dark(_brandConfig),
        builder: (context, child) => textScaler == null
            ? child!
            : MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
        home: const SubscriptionScreen(),
      ),
    );

class _CountingAdapter extends FakePurchaseAdapter {
  _CountingAdapter()
      : super(
          snapshot: const PaywallSnapshot(
            phase: PaywallPhase.idle,
            products: [_product],
          ),
        );

  int purchaseCalls = 0;

  @override
  Future<PurchaseOutcome> purchase(PurchaseProduct product) {
    purchaseCalls++;
    return Future.value(const PurchaseOutcome(PaywallPhase.success));
  }
}

const _brandConfig = BrandConfig(
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
      greeting: 'Ой, друзі, ну це щось...',
      loginTitle: 'Готуйте з Олександром',
      paywallTitle: 'Колекції Олександра',
    ),
    derived: DerivedBrandColors(
      accentPressed: '#4B5E70',
      accentOnDark: '#6B8092',
      onAccent: '#FFFFFF',
      lightCtaMode: 'accentFill',
    ),
    heroPhotos: [],
  ),
);

const _bootstrap = TenantBootstrap(
  tenantSlug: 'ohorodnik-oleksandr',
  brandConfig: _brandConfig,
  configVersion: 'test',
);
