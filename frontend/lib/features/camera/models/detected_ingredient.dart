import 'package:freezed_annotation/freezed_annotation.dart';

part 'detected_ingredient.freezed.dart';
part 'detected_ingredient.g.dart';

@freezed
class DetectedIngredient with _$DetectedIngredient {
  const factory DetectedIngredient({
    required String name,
    @Default(0.0) double confidence,
    @Default(true) bool isConfirmed,
    String? notes,
    @Default('') String id,
  }) = _DetectedIngredient;

  factory DetectedIngredient.fromJson(Map<String, dynamic> json) =>
      _$DetectedIngredientFromJson(json);
}

@freezed
class PhotoSearchRequest with _$PhotoSearchRequest {
  const factory PhotoSearchRequest({
    required String image,
    String? chefId,
    @Default(10) int maxResults,
  }) = _PhotoSearchRequest;

  factory PhotoSearchRequest.fromJson(Map<String, dynamic> json) =>
      _$PhotoSearchRequestFromJson(json);
}

@freezed
class PhotoSearchResponse with _$PhotoSearchResponse {
  const factory PhotoSearchResponse({
    @Default([]) List<String> ingredients,
    @Default([]) List<Map<String, dynamic>> suggestedRecipes,
    @Default(0.0) double confidenceScore,
  }) = _PhotoSearchResponse;

  factory PhotoSearchResponse.fromJson(Map<String, dynamic> json) =>
      _$PhotoSearchResponseFromJson(json);
}

@freezed
class CameraState with _$CameraState {
  const factory CameraState({
    @Default(false) bool isInitialized,
    @Default(false) bool isLoading,
    @Default(false) bool hasPermission,
    String? error,
    String? capturedImagePath,
  }) = _CameraState;
}

@freezed
class PhotoSearchState with _$PhotoSearchState {
  const factory PhotoSearchState({
    @Default(false) bool isLoading,
    @Default([]) List<DetectedIngredient> detectedIngredients,
    @Default([]) List<Map<String, dynamic>> suggestedRecipes,
    @Default(0.0) double confidence,
    String? error,
  }) = _PhotoSearchState;
}
