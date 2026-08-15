import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/router/app_router.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/app/theme/tokens/app_tokens.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/core/branding/brand_providers.dart';
import 'package:frontend/core/branding/tenant_bootstrap.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [tenantBootstrapProvider.overrideWithValue(_bootstrap)],
      child: MaterialApp(
        theme: AppThemeV2.light(_bootstrap.brandConfig),
        home: AdaptiveNavigationShell(
          selectedIndex: 1,
          onDestinationSelected: (_) {},
          child: const KeyedSubtree(
            key: ValueKey('tab-content'),
            child: Text('Збережений стан вкладки'),
          ),
        ),
      ),
    ));
  }

  testWidgets('uses bottom navigation at 390 pixels', (tester) async {
    await pumpShell(tester, const Size(390, 844));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Збережений стан вкладки'), findsOneWidget);
  });

  testWidgets('uses navigation rail at 768 pixels', (tester) async {
    await pumpShell(tester, const Size(768, 1024));

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(find.byType(NavigationBar), findsNothing);
    expect(rail.extended, isFalse);
    expect(find.text('Збережений стан вкладки'), findsOneWidget);
  });

  testWidgets('uses desktop composition at 1280 pixels', (tester) async {
    await pumpShell(tester, const Size(1280, 900));

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Огороднік Олександр'), findsOneWidget);
    expect(find.text('Сканувати'), findsOneWidget);
    expect(find.byTooltip('Налаштування'), findsOneWidget);
    expect(find.byType(ConstrainedBox), findsWidgets);
    expect(find.text('Збережений стан вкладки'), findsOneWidget);
  });

  testWidgets('a page still gets desktop width at the chrome breakpoint',
      (tester) async {
    double? pageWidth;
    await tester.binding
        .setSurfaceSize(const Size(AppLayout.desktopBreakpoint, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [tenantBootstrapProvider.overrideWithValue(_bootstrap)],
      child: MaterialApp(
        theme: AppThemeV2.light(_bootstrap.brandConfig),
        home: AdaptiveNavigationShell(
          selectedIndex: 1,
          onDestinationSelected: (_) {},
          child: LayoutBuilder(builder: (context, constraints) {
            pageWidth = constraints.maxWidth;
            return const SizedBox.shrink();
          }),
        ),
      ),
    ));

    // The rail eats into the page, so a page measuring itself against the
    // window breakpoint would draw its narrow layout inside desktop chrome.
    expect(pageWidth, isNotNull);
    expect(pageWidth, greaterThanOrEqualTo(AppLayout.contentDesktopBreakpoint));
  });
}

final _bootstrap = TenantBootstrap(
  tenantSlug: 'ohorodnik-oleksandr',
  configVersion: 'test',
  brandConfig: BrandConfig.fromJson({
    'schemaVersion': 1,
    'tenantSlug': 'ohorodnik-oleksandr',
    'locale': 'uk',
    'brand': {
      'name': 'Огороднік Олександр',
      'creatorName': 'Олександр',
      'avatar': 'PENDING:/avatar.png',
      'accent': '#5D7183',
      'font': 'grotesque',
      'voice': {
        'greeting': 'Вітаю',
        'loginTitle': 'Вхід',
        'paywallTitle': 'Premium',
      },
      'derived': {
        'accentPressed': '#4B5E70',
        'accentOnDark': '#6B8092',
        'onAccent': '#FFFFFF',
        'lightCtaMode': 'accentFill',
      },
    },
  }),
);
