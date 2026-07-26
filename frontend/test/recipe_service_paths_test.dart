import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/recipes/models/recipe.dart';
import 'package:frontend/features/recipes/services/recipe_service.dart';

/// The catalogue router mounts its list and create handlers on "/", so
/// "/api/v1/recipes" answers 307. Chrome follows that redirect; WebKit refuses
/// to follow one on a preflighted cross-origin request, which took the whole
/// catalogue down on iOS while every desktop browser looked healthy. Ask for
/// the canonical path so no redirect is involved.
void main() {
  test('the catalogue list is fetched from the non-redirecting path', () async {
    final adapter = _RecordingAdapter(
      body: {'recipes': <dynamic>[], 'total': 0},
    );
    final service = RecipeService(_client(adapter));

    await service.getRecipes();

    expect(adapter.paths.single, '/api/v1/recipes/');
  });

  test('creating a recipe posts to the non-redirecting path', () async {
    final adapter = _RecordingAdapter(statusCode: 201, body: _recipeJson);
    final service = RecipeService(_client(adapter));

    await service.createRecipe(Recipe.fromJson(_recipeJson));

    expect(adapter.paths.single, '/api/v1/recipes/');
  });
}

const _recipeJson = <String, dynamic>{
  'id': 'recipe-1',
  'title': 'Капрезе 2.0',
  'description': '',
  'ingredients': <dynamic>[],
  'instructions': <dynamic>[],
  'prep_time_minutes': 10,
  'cook_time_minutes': 20,
  'servings': 2,
  'difficulty': 2,
  'chef_id': 'chef-1',
  'created_at': '2026-07-26T00:00:00Z',
  'updated_at': '2026-07-26T00:00:00Z',
};

ApiClient _client(_RecordingAdapter adapter) => ApiClient(
      dio: Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter,
      tokenProvider: () async => null,
      tenantSlug: 'ohorodnik-oleksandr',
      locale: 'uk',
      getRetryDelays: const [],
    );

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.statusCode = 200, required this.body});

  final int statusCode;
  final Map<String, dynamic> body;
  final List<String> paths = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
