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
import 'package:frontend/features/recipes/presentation/pages/recipe_detail_page.dart';
import 'package:frontend/features/recipes/providers/recipe_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets('opening a material names the collection that granted it',
      (tester) async {
    // A free preview is the collection's grant, so the link to the material
    // has to carry the collection or the detail route re-locks it.
    SharedPreferences.setMockInitialValues({});
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;

    final container = ProviderContainer(
      overrides: [
        tenantBootstrapProvider.overrideWithValue(_bootstrap),
        authProvider.overrideWith((ref) => AuthNotifier.testing()),
        collectionDetailProvider('collection-1')
            .overrideWith((ref) async => _previewCollection),
        recipeDetailProvider((
          recipeId: 'recipe-0',
          collectionId: 'collection-1'
        )).overrideWith((ref) async => _previewCollection.items.first.content),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider)
      ..go('/collections/collection-1');
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppThemeV2.light(_bootstrap.brandConfig),
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();

    final card =
        find.bySemanticsLabel('Відкрити матеріал Безкоштовний матеріал');
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();

    final opened =
        tester.widget<RecipeDetailPage>(find.byType(RecipeDetailPage));
    expect(opened.recipeId, 'recipe-0');
    expect(opened.collectionId, 'collection-1');
  });

  testWidgets('a preview card fits its badges at every breakpoint',
      (tester) async {
    // Kind, free preview and resume together are the tallest a card gets, and
    // the grid hands every tile the same fixed height.
    SharedPreferences.setMockInitialValues(
        {'col03.last-item.collection-1': 'item-0'});
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final width in [390.0, 768.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 1600);
      final container = ProviderContainer(
        overrides: [
          tenantBootstrapProvider.overrideWithValue(_bootstrap),
          authProvider.overrideWith((ref) => AuthNotifier.testing()),
          collectionDetailProvider('collection-1')
              .overrideWith((ref) async => _previewCollection),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider)
        ..go('/collections/collection-1');
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppThemeV2.light(_bootstrap.brandConfig),
          routerConfig: router,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Продовжити'), findsOneWidget, reason: 'width: $width');
      expect(tester.takeException(), isNull, reason: 'width: $width');
    }
  });
}

final _previewCollection = ContentCollection.fromJson(_previewCollectionJson);

const Map<String, dynamic> _previewCollectionJson = {
  'id': 'collection-1',
  'slug': 'maisternia',
  'title': 'Майстерня',
  'description': 'Авторська добірка',
  'item_count': 1,
  'is_premium': true,
  'is_locked': true,
  'items': [
    {
      'id': 'item-0',
      'position': 0,
      'is_preview': true,
      'content': {
        'id': 'recipe-0',
        'chef_id': 'chef-1',
        'title': 'Безкоштовний матеріал',
        'description': 'Опис',
        'content_kind': 'recipe',
        'difficulty': 1,
        'prep_time_minutes': 0,
        'cook_time_minutes': 0,
        'total_time_minutes': 0,
        'servings': 1,
        'is_premium': true,
        'is_locked': false,
        'created_at': '2026-07-15T00:00:00Z',
        'updated_at': '2026-07-15T00:00:00Z',
      },
    },
  ],
};

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
        tenantBootstrapProvider.overrideWithValue(_bootstrap),
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
