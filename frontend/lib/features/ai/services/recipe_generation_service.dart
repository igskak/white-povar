import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/generated_recipe.dart';

sealed class RecipeGenerationEvent {
  const RecipeGenerationEvent();
}

class RecipeGenerationStatus extends RecipeGenerationEvent {
  const RecipeGenerationStatus(this.message);
  final String message;
}

class RecipeGenerationComplete extends RecipeGenerationEvent {
  const RecipeGenerationComplete(this.recipe);
  final GeneratedRecipe recipe;
}

class RecipeGenerationFailure extends RecipeGenerationEvent {
  const RecipeGenerationFailure(this.message);
  final String message;
}

class RecipeGenerationService {
  RecipeGenerationService(this._apiClient);
  final ApiClient _apiClient;

  /// The endpoint accepts only an explicit true consent flag. This method is
  /// intentionally called only after the dedicated consent dialog.
  Stream<RecipeGenerationEvent> generate(String prompt) async* {
    try {
      final response = await _apiClient.dio.post<ResponseBody>(
        '/api/v1/ai/recipe-generation/stream',
        data: {'prompt': prompt, 'generation_consent': true},
        options: Options(responseType: ResponseType.stream),
      );
      final body = response.data;
      if (body == null) {
        yield const RecipeGenerationFailure('AI не повернув відповідь.');
        return;
      }
      var event = 'message';
      await for (final line in body.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          final data =
              jsonDecode(line.substring(5).trim()) as Map<String, dynamic>;
          final message = data['message']?.toString();
          if (event == 'status' && message != null) {
            yield RecipeGenerationStatus(message);
          } else if (event == 'recipe') {
            yield RecipeGenerationComplete(GeneratedRecipe.fromJson(data));
          } else if (event == 'error') {
            yield RecipeGenerationFailure(
                message ?? 'Не вдалося створити рецепт.');
          }
        }
      }
    } on DioException catch (error) {
      final message = error.response?.data is Map<String, dynamic>
          ? (error.response!.data['detail']?.toString())
          : null;
      yield RecipeGenerationFailure(
          message ?? 'AI-генерація зараз недоступна.');
    } catch (_) {
      yield const RecipeGenerationFailure('AI-генерація зараз недоступна.');
    }
  }
}

final recipeGenerationServiceProvider = Provider<RecipeGenerationService>(
    (ref) => RecipeGenerationService(ref.watch(apiClientProvider)));
