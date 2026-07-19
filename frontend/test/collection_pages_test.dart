import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/router/app_router.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/core/branding/brand_providers.dart';
import 'package:frontend/core/branding/tenant_bootstrap.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/collections/models/collection.dart';
import 'package:frontend/features/collections/presentation/pages/collection_list_page.dart';
import 'package:frontend/features/collections/providers/collection_provider.dart';

void main() {
  testWidgets('collection list uses 1, 2 and 3 columns at handoff widths',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final expectation in <double, int>{
      390: 1,
      768: 2,
      1280: 3,
    }.entries) {
      tester.view.physicalSize = Size(expectation.key, 900);
      await tester.pumpWidget(_collectionApp());
      await tester.pump();

      final grid = tester.widget<GridView>(
        find.byKey(const ValueKey('collections-responsive-grid')),
      );
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(
        delegate.crossAxisCount,
        expectation.value,
        reason: 'width: ${expectation.key}',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('locked collection cards keep premium and lock semantics',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_collectionApp());
    await tester.pump();

    expect(find.text('Premium'), findsWidgets);
    expect(find.text('Закрито'), findsWidgets);
    expect(
        find.bySemanticsLabel('Відкрити колекцію Колекція 1'), findsOneWidget);
  });

  testWidgets('collections route stays inside the adaptive app shell',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer(
      overrides: [
        tenantBootstrapProvider.overrideWithValue(_bootstrap),
        authProvider.overrideWith((ref) => AuthNotifier.testing()),
        collectionListProvider.overrideWith((ref) async => _collections),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider)..go('/collections');
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppThemeV2.light(_bootstrap.brandConfig),
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AdaptiveNavigationShell), findsOneWidget);
    expect(find.byKey(const ValueKey('collections-responsive-grid')),
        findsOneWidget);
  });
}

final _collections = List.generate(
  4,
  (index) => ContentCollection(
    id: 'collection-$index',
    slug: 'collection-$index',
    title: 'Колекція ${index + 1}',
    description: 'Авторська добірка',
    itemCount: 8,
    isPremium: true,
    isLocked: true,
  ),
);

Widget _collectionApp() => ProviderScope(
      overrides: [
        collectionListProvider.overrideWith(
          (ref) async => _collections,
        ),
      ],
      child: const MaterialApp(home: CollectionListPage()),
    );

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
