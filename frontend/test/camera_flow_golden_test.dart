import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/camera/models/detected_ingredient.dart';
import 'package:frontend/features/camera/presentation/pages/camera_capture_page.dart';
import 'package:frontend/features/camera/presentation/pages/ingredient_review_page.dart';
import 'package:frontend/features/camera/presentation/pages/photo_search_results_page.dart';
import 'package:frontend/features/camera/providers/camera_provider.dart';
import 'package:frontend/features/camera/providers/photo_search_provider.dart';
import 'package:frontend/features/camera/services/camera_service.dart';
import 'package:frontend/features/camera/services/image_processing_service.dart';
import 'package:frontend/features/camera/services/photo_search_service.dart';
import 'package:frontend/features/recipes/models/recipe.dart';

void main() {
  testWidgets('Camera flow goldens at handoff breakpoints', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    final image = XFile(
      '${Directory.current.path}/test/goldens/design_system_primitives.png',
    );

    for (final state in _CameraFixtureState.values) {
      for (final width in [390.0, 768.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(
          _cameraApp(
            state,
            image,
            fixtureKey: '${state.name}-$width',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await expectLater(
          find.byType(_pageType(state)),
          matchesGoldenFile(
            'goldens/camera_${state.name}_${width.toInt()}.png',
          ),
        );
        expect(tester.takeException(), isNull,
            reason: '${state.name} at $width');
      }
    }
  }, tags: 'golden');
}

Type _pageType(_CameraFixtureState state) => switch (state) {
      _CameraFixtureState.capture => CameraCapturePage,
      _CameraFixtureState.review => IngredientReviewPage,
      _CameraFixtureState.results => PhotoSearchResultsPage,
    };

Widget _cameraApp(
  _CameraFixtureState state,
  XFile image, {
  required String fixtureKey,
}) {
  final photoSearch = _GoldenPhotoSearchNotifier()
    ..seed(PhotoSearchState(
      detectedIngredients:
          state == _CameraFixtureState.capture ? const [] : _ingredients,
      suggestedRecipes:
          state == _CameraFixtureState.results ? _recipeMaps : const [],
      confidence: .79,
    ));
  return ProviderScope(
    key: ValueKey(fixtureKey),
    overrides: [
      cameraProvider.overrideWith(
        (_) => CameraNotifier(
          cameraService: _GrantedCameraService(),
          imageProcessingService: ImageProcessingService(),
        ),
      ),
      photoSearchProvider.overrideWith((_) => photoSearch),
      ingredientEditProvider.overrideWith(
        (_) => IngredientEditNotifier()
          ..setIngredients(
            state == _CameraFixtureState.capture ? const [] : _ingredients,
          ),
      ),
      authProvider.overrideWith((_) => AuthNotifier.testing()),
    ],
    child: MaterialApp(
      theme: AppThemeV2.light(_brand),
      home: switch (state) {
        _CameraFixtureState.capture => const CameraCapturePage(),
        _CameraFixtureState.review =>
          IngredientReviewPage(capturedImage: image),
        _CameraFixtureState.results => const PhotoSearchResultsPage(),
      },
    ),
  );
}

enum _CameraFixtureState { capture, review, results }

class _GrantedCameraService extends CameraService {
  @override
  Future<bool> isCameraAvailable() async => true;

  @override
  Future<CameraPermissionState> cameraPermissionState() async =>
      CameraPermissionState.granted;

  @override
  Future<bool> requestCameraPermission() async => true;

  @override
  Future<void> initializePreview() async {}

  @override
  Future<void> disposePreview() async {}
}

class _GoldenPhotoSearchNotifier extends PhotoSearchNotifier {
  _GoldenPhotoSearchNotifier() : super(photoSearchService: _service);

  void seed(PhotoSearchState value) => state = value;

  static final _service = PhotoSearchService(
    apiClient: ApiClient(
      baseUrl: 'https://example.invalid',
      tokenProvider: () async => null,
      tenantSlug: 'ohorodnik-oleksandr',
      locale: 'uk',
    ),
  );
}

const _ingredients = [
  DetectedIngredient(
    id: 'tomatoes',
    name: 'Томати',
    confidence: .96,
    isConfirmed: true,
  ),
  DetectedIngredient(
    id: 'mozzarella',
    name: 'Моцарела',
    confidence: .88,
    isConfirmed: true,
  ),
  DetectedIngredient(
    id: 'basil',
    name: 'Базилік',
    confidence: .62,
    isConfirmed: false,
  ),
];

final _recipeMaps = List.generate(
  6,
  (index) => Recipe(
    id: 'camera-result-$index',
    title: [
      'Капрезе 2.0',
      'Томатний тарт',
      'Паста з моцарелою',
      'Теплий салат',
      'Фокача з томатами',
      'Запечені овочі',
    ][index],
    description: 'Рецепт із продуктів, знайдених на фото.',
    chefId: 'chef',
    cuisine: 'Італійська',
    category: 'Вечеря',
    difficulty: 2,
    prepTimeMinutes: 10,
    cookTimeMinutes: 20,
    totalTimeMinutes: 30,
    servings: 4,
    ingredients: const [
      Ingredient(
        id: 'result-tomatoes',
        recipeId: 'camera-result',
        name: 'Томати',
        amount: 4,
        unit: 'шт.',
        order: 0,
      ),
      Ingredient(
        id: 'result-mozzarella',
        recipeId: 'camera-result',
        name: 'Моцарела',
        amount: 200,
        unit: 'г',
        order: 1,
      ),
    ],
    instructions: const ['Підготуйте продукти.', 'Завершіть страву.'],
    images: const [],
    tags: const ['camera'],
    isFeatured: index == 0,
    createdAt: DateTime(2026, 7, 19),
    updatedAt: DateTime(2026, 7, 19),
  ).toJson(),
);

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
