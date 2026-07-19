import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/router/route_models.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/ai/models/generated_recipe.dart';
import 'package:frontend/features/ai/services/recipe_generation_service.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/recipes/models/recipe.dart';
import 'package:frontend/features/recipes/repositories/recipe_repository.dart';
import 'package:frontend/features/search/presentation/pages/search_page.dart';
import 'package:frontend/features/search/providers/search_provider.dart';
import 'package:frontend/features/voice/providers/voice_input_provider.dart';
import 'package:frontend/features/voice/services/speech_recognition_service.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('UI-04 search discovery', () {
    testWidgets('tag deep link searches the canonical tag directly',
        (tester) async {
      final repository = _SearchRepository();
      await tester.pumpWidget(_testApp(
        repository: repository,
        initialRoute: const SearchRouteLocation(tag: 'maisternia-oleksandra'),
      ));

      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.queries, ['maisternia-oleksandra']);
      expect(find.text('Тег: maisternia-oleksandra'), findsOneWidget);
    });

    testWidgets('query changes are serialized into the web route',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/search',
        routes: [
          GoRoute(
            path: '/search',
            builder: (_, state) => ProviderScope(
              overrides: [
                recipeRepositoryProvider.overrideWithValue(_SearchRepository()),
                authProvider.overrideWith((ref) => AuthNotifier.testing()),
              ],
              child: SearchPage(
                initialRoute: SearchRouteLocation.fromUri(state.uri),
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(
        theme: AppThemeV2.light(_brandConfig),
        routerConfig: router,
      ));

      await tester.enterText(find.byType(TextField), 'борщ');
      await tester.pump();

      expect(router.routeInformationProvider.value.uri.toString(),
          '/search?q=%D0%B1%D0%BE%D1%80%D1%89');
    });

    testWidgets('voice consent writes an editable final transcript to search',
        (tester) async {
      final speech = _FakeSpeechRecognitionService();
      final repository = _SearchRepository();
      await tester.pumpWidget(_testApp(
        repository: repository,
        speechRecognitionService: speech,
      ));

      await tester.tap(find.byTooltip('Голосове введення'));
      await tester.pump();
      expect(
        find.textContaining('Аудіо не зберігається та не надсилається'),
        findsOneWidget,
      );

      await tester.tap(find.text('Дозволити мікрофон'));
      await tester.pump();
      expect(speech.permissionRequested, isTrue);
      expect(find.textContaining('Слухаємо'), findsOneWidget);

      speech.emitTranscript('паста з томатами', true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'паста з томатами',
      );
      expect(repository.queries, contains('паста з томатами'));
    });

    testWidgets('denied microphone keeps typed search available',
        (tester) async {
      final speech = _FakeSpeechRecognitionService(
        permissionState: VoicePermissionState.denied,
      );
      await tester.pumpWidget(_testApp(
        repository: _SearchRepository(),
        speechRecognitionService: speech,
      ));

      await tester.tap(find.byTooltip('Голосове введення'));
      await tester.pump();
      await tester.tap(find.text('Дозволити мікрофон'));
      await tester.pump();

      expect(
          find.textContaining('можете ввести запит текстом'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'борщ');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'борщ',
      );
    });

    testWidgets('AI recipe generation needs separate consent before streaming',
        (tester) async {
      final speech = _FakeSpeechRecognitionService();
      final generation = _FakeRecipeGenerationService();
      await tester.pumpWidget(_testApp(
        repository: _NoMatchVoiceRepository(),
        speechRecognitionService: speech,
        recipeGenerationService: generation,
      ));

      await tester.tap(find.byTooltip('Голосове введення'));
      await tester.pump();
      await tester.tap(find.text('Дозволити мікрофон'));
      await tester.pump();
      speech.emitTranscript('щось нове з томатами', true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Створити AI-рецепт'));
      await tester.pump();

      expect(find.text('Погоджуюсь і створюю'), findsOneWidget);
      expect(generation.prompts, isEmpty);
      await tester.tap(find.text('Скасувати'));
      await tester.pump();
      expect(generation.prompts, isEmpty);

      await tester.tap(find.text('Створити AI-рецепт'));
      await tester.pump();
      await tester.tap(find.text('Погоджуюсь і створюю'));
      await tester.pump();
      await tester.pump();
      expect(generation.prompts, ['щось нове з томатами']);
      expect(find.text('Створено AI, не опублікований рецепт автора'),
          findsOneWidget);
    });

    testWidgets('result layouts have no exceptions at 390, 768 and 1280',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [390.0, 768.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(_testApp(repository: _SearchRepository()));
        await tester.enterText(find.byType(TextField), 'паста');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'width: $width');
      }
    });

    testWidgets('desktop keeps a filter rail and three-column result grid',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(_testApp(repository: _SearchRepository()));

      expect(
          find.byKey(const ValueKey('desktop-search-layout')), findsOneWidget);
      expect(find.text('Швидкі добірки'), findsOneWidget);
      expect(find.text('Пошук'), findsNothing);
      expect(find.text('Фільтри'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'паста');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      final grid = tester.widget<GridView>(
        find.byKey(const ValueKey('search-results-grid')),
      );
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
      expect(find.text('Обраний рецепт'), findsNothing);
    });

    test('debounce and cancellation never publish stale results', () async {
      final repository = _DeferredSearchRepository();
      final container = ProviderContainer(overrides: [
        recipeRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(simpleTextSearchProvider.notifier);

      notifier.searchRecipes('перший');
      await Future<void>.delayed(const Duration(milliseconds: 260));
      notifier.searchRecipes('другий');
      await Future<void>.delayed(const Duration(milliseconds: 260));
      repository.complete('перший', [_recipe('stale')]);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(simpleTextSearchProvider).query, 'другий');
      expect(container.read(simpleTextSearchProvider).results, isEmpty);

      repository.complete('другий', [_recipe('fresh')]);
      await Future<void>.delayed(Duration.zero);
      expect(
          container.read(simpleTextSearchProvider).results.single.id, 'fresh');
    });
  });
}

Widget _testApp({
  required RecipeRepository repository,
  SearchRouteLocation? initialRoute,
  SpeechRecognitionService? speechRecognitionService,
  RecipeGenerationService? recipeGenerationService,
}) =>
    ProviderScope(
      overrides: [
        recipeRepositoryProvider.overrideWithValue(repository),
        authProvider.overrideWith((ref) => AuthNotifier.testing()),
        if (speechRecognitionService != null)
          speechRecognitionServiceProvider
              .overrideWithValue(speechRecognitionService),
        if (recipeGenerationService != null)
          recipeGenerationServiceProvider
              .overrideWithValue(recipeGenerationService),
      ],
      child: MaterialApp(
        theme: AppThemeV2.light(_brandConfig),
        home: SearchPage(initialRoute: initialRoute),
      ),
    );

class _SearchRepository extends _RepositoryBase {
  final List<String> queries = [];

  @override
  Future<List<Recipe>> searchRecipes(String query,
      {CancelToken? cancelToken}) async {
    queries.add(query);
    return [_recipe('search-$query')];
  }
}

class _DeferredSearchRepository extends _RepositoryBase {
  final Map<String, Completer<List<Recipe>>> _requests = {};

  @override
  Future<List<Recipe>> searchRecipes(String query,
          {CancelToken? cancelToken}) =>
      (_requests[query] ??= Completer<List<Recipe>>()).future;

  void complete(String query, List<Recipe> recipes) =>
      _requests[query]!.complete(recipes);
}

class _NoMatchVoiceRepository extends _SearchRepository {
  @override
  Future<VoiceIntentSearchResult> searchVoiceIntent(String transcript,
          {CancelToken? cancelToken}) async =>
      const VoiceIntentSearchResult(recipes: [], confirmationRequired: []);
}

class _FakeRecipeGenerationService extends RecipeGenerationService {
  _FakeRecipeGenerationService()
      : super(ApiClient(
          baseUrl: 'https://example.invalid',
          tokenProvider: () async => null,
          tenantSlug: 'ohorodnik-oleksandr',
          locale: 'uk',
        ));

  final List<String> prompts = [];

  @override
  Stream<RecipeGenerationEvent> generate(String prompt) async* {
    prompts.add(prompt);
    yield const RecipeGenerationStatus('Створюємо структуру рецепта…');
    yield const RecipeGenerationComplete(GeneratedRecipe(
      title: 'Томатна вечеря',
      description: 'Тестовий AI-рецепт.',
      servings: 2,
      totalTimeMinutes: 20,
      ingredients: [GeneratedIngredient(name: 'томати', amount: '400 г')],
      steps: ['Прогрійте томати.'],
      safetyNote: 'Перевірте склад продуктів.',
      attribution: 'Створено AI, не опублікований рецепт автора',
    ));
  }
}

class _FakeSpeechRecognitionService implements SpeechRecognitionService {
  _FakeSpeechRecognitionService({
    this.permissionState = VoicePermissionState.granted,
  });

  final VoicePermissionState permissionState;
  bool permissionRequested = false;
  VoiceTranscriptCallback? _onTranscript;
  VoiceStatusCallback? _onStatus;

  @override
  Future<void> cancel() async {
    _onStatus?.call(false);
  }

  void emitTranscript(String text, bool isFinal) =>
      _onTranscript?.call(text, isFinal);

  @override
  Future<VoicePermissionState> requestPermission() async {
    permissionRequested = true;
    return permissionState;
  }

  @override
  Future<bool> start({
    required VoiceTranscriptCallback onTranscript,
    required VoiceStatusCallback onStatus,
    required VoiceErrorCallback onError,
  }) async {
    _onTranscript = onTranscript;
    _onStatus = onStatus;
    onStatus(true);
    return true;
  }

  @override
  Future<void> stop() async {
    _onStatus?.call(false);
  }
}

abstract class _RepositoryBase implements RecipeRepository {
  @override
  Future<VoiceIntentSearchResult> searchVoiceIntent(String transcript,
          {CancelToken? cancelToken}) async =>
      VoiceIntentSearchResult(
        recipes: await searchRecipes(transcript, cancelToken: cancelToken),
        confirmationRequired: const [],
      );

  @override
  Future<Recipe> createRecipe(Recipe recipe) async => recipe;
  @override
  Future<void> deleteRecipe(String id) async {}
  @override
  Future<Recipe?> getRecipe(String id) async => _recipe(id);
  @override
  Future<List<Recipe>> getRecipes(
          {String? cuisine,
          String? category,
          int? difficulty,
          int? maxTime,
          bool? isFeatured,
          int limit = 20,
          int offset = 0}) async =>
      [_recipe('all')];
  @override
  Future<List<Recipe>> getRecipesByChef(String chefId,
          {int limit = 20, int offset = 0}) async =>
      [_recipe('chef')];
  @override
  Future<List<Recipe>> getFeaturedRecipes({int limit = 10}) async =>
      [_recipe('featured')];
  @override
  Future<Recipe> updateRecipe(Recipe recipe) async => recipe;
}

Recipe _recipe(String id) => Recipe(
      id: id,
      title: 'Тестова паста',
      description: 'Швидка вечеря',
      chefId: 'chef',
      cuisine: 'Українська',
      category: 'Вечеря',
      difficulty: 1,
      prepTimeMinutes: 5,
      cookTimeMinutes: 10,
      totalTimeMinutes: 15,
      servings: 2,
      ingredients: const [],
      instructions: const [],
      images: const [],
      tags: const ['maisternia-oleksandra'],
      isFeatured: false,
      isPremium: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

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
      greeting: 'Ой, друзі',
      loginTitle: 'Готуйте',
      paywallTitle: 'Колекції',
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
