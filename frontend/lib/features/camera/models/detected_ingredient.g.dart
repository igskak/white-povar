// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'detected_ingredient.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DetectedIngredientImpl _$$DetectedIngredientImplFromJson(
        Map<String, dynamic> json) =>
    _$DetectedIngredientImpl(
      name: json['name'] as String,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      isConfirmed: json['isConfirmed'] as bool? ?? true,
      notes: json['notes'] as String?,
      id: json['id'] as String? ?? '',
    );

Map<String, dynamic> _$$DetectedIngredientImplToJson(
        _$DetectedIngredientImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'confidence': instance.confidence,
      'isConfirmed': instance.isConfirmed,
      'notes': instance.notes,
      'id': instance.id,
    };

_$PhotoSearchRequestImpl _$$PhotoSearchRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$PhotoSearchRequestImpl(
      image: json['image'] as String,
      chefId: json['chefId'] as String?,
      maxResults: (json['maxResults'] as num?)?.toInt() ?? 10,
    );

Map<String, dynamic> _$$PhotoSearchRequestImplToJson(
        _$PhotoSearchRequestImpl instance) =>
    <String, dynamic>{
      'image': instance.image,
      'chefId': instance.chefId,
      'maxResults': instance.maxResults,
    };

_$PhotoSearchResponseImpl _$$PhotoSearchResponseImplFromJson(
        Map<String, dynamic> json) =>
    _$PhotoSearchResponseImpl(
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      suggestedRecipes: (json['suggestedRecipes'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$$PhotoSearchResponseImplToJson(
        _$PhotoSearchResponseImpl instance) =>
    <String, dynamic>{
      'ingredients': instance.ingredients,
      'suggestedRecipes': instance.suggestedRecipes,
      'confidenceScore': instance.confidenceScore,
    };
