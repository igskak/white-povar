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
    required this.tags,
    required this.isFeatured,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      chefId: json['chef_id'] as String,
      cuisine: json['cuisine'] as String,
      category: json['category'] as String,
      difficulty: json['difficulty'] as int,
      prepTimeMinutes: json['prep_time_minutes'] as int,
      cookTimeMinutes: json['cook_time_minutes'] as int,
      totalTimeMinutes: json['total_time_minutes'] as int,
      servings: json['servings'] as int,
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      instructions: List<String>.from(json['instructions'] as List),
      images: List<String>.from(json['images'] as List? ?? []),
      tags: List<String>.from(json['tags'] as List? ?? []),
      isFeatured: json['is_featured'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
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
      id: json['id'] as String,
      recipeId: json['recipe_id'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      unit: json['unit'] as String,
      notes: json['notes'] as String?,
      order: json['order'] as int,
    );
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
