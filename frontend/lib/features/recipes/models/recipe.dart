import 'package:equatable/equatable.dart';

class Recipe extends Equatable {
  final String id;
  final String title;
  final String description;
  final String chefId;
  final String cuisine;
  final String category;
  final int difficulty;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int totalTimeMinutes;
  final int servings;
  final List<Ingredient> ingredients;
  final List<String> instructions;
  final List<String> images;
  final String? videoUrl;
  final String? videoFilePath;
  final List<String> tags;
  final bool isFeatured;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.chefId,
    required this.cuisine,
    required this.category,
    required this.difficulty,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.totalTimeMinutes,
    required this.servings,
    required this.ingredients,
    required this.instructions,
    required this.images,
    this.videoUrl,
    this.videoFilePath,
    required this.tags,
    required this.isFeatured,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'].toString(), // Handle UUID conversion
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      chefId: json['chef_id'].toString(), // Handle UUID conversion
      cuisine: json['cuisine']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      difficulty: _parseIntSafely(json['difficulty']) ?? 1,
      prepTimeMinutes: _parseIntSafely(json['prep_time_minutes']) ?? 0,
      cookTimeMinutes: _parseIntSafely(json['cook_time_minutes']) ?? 0,
      totalTimeMinutes: _parseIntSafely(json['total_time_minutes']) ?? 0,
      servings: _parseIntSafely(json['servings']) ?? 1,
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      instructions: _parseStringList(json['instructions']),
      images: _parseStringList(json['images']),
      videoUrl: json['video_url']?.toString(),
      videoFilePath: json['video_file_path']?.toString(),
      tags: _parseStringList(json['tags']),
      isFeatured: json['is_featured'] == true,
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
    );
  }

  // Helper methods for safe parsing
  static int? _parseIntSafely(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'chef_id': chefId,
      'cuisine': cuisine,
      'category': category,
      'difficulty': difficulty,
      'prep_time_minutes': prepTimeMinutes,
      'cook_time_minutes': cookTimeMinutes,
      'total_time_minutes': totalTimeMinutes,
      'servings': servings,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'instructions': instructions,
      'images': images,
      'video_url': videoUrl,
      'video_file_path': videoFilePath,
      'tags': tags,
      'is_featured': isFeatured,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        chefId,
        cuisine,
        category,
        difficulty,
        prepTimeMinutes,
        cookTimeMinutes,
        totalTimeMinutes,
        servings,
        ingredients,
        instructions,
        images,
        videoUrl,
        videoFilePath,
        tags,
        isFeatured,
        createdAt,
        updatedAt,
      ];
}

class Ingredient extends Equatable {
  final String id;
  final String recipeId;
  final String name;
  final double amount;
  final String unit;
  final String? notes;
  final int order;

  const Ingredient({
    required this.id,
    required this.recipeId,
    required this.name,
    required this.amount,
    required this.unit,
    this.notes,
    required this.order,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'].toString(), // Handle UUID conversion
      recipeId: json['recipe_id'].toString(), // Handle UUID conversion
      name: json['name']?.toString() ?? '',
      amount: _parseDoubleSafely(json['amount']) ?? 0.0,
      unit: json['unit']?.toString() ?? '',
      notes: json['notes']?.toString(),
      order: Recipe._parseIntSafely(json['order']) ?? 0,
    );
  }

  // Helper method for safe double parsing
  static double? _parseDoubleSafely(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipe_id': recipeId,
      'name': name,
      'amount': amount,
      'unit': unit,
      'notes': notes,
      'order': order,
    };
  }

  @override
  List<Object?> get props => [id, recipeId, name, amount, unit, notes, order];
}
