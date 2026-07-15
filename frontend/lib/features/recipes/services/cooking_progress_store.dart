import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe.dart';

/// A deliberately small offline cache: one active cooking session per device.
/// It contains no account identity and is cleared when the user signs out.
class CookingProgressStore {
  static const _key = 'core03.active-cooking.v1';
  static const _savedRecipesKey = 'core03.saved-recipes.v1';

  Future<CookingProgress?> read() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return null;
    try {
      return CookingProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> save(CookingProgress progress) async {
    await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode(progress.toJson()));
  }

  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);

  Future<List<Recipe>> readSavedRecipes() async {
    final raw =
        (await SharedPreferences.getInstance()).getString(_savedRecipesKey);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((value) => Recipe.fromJson(value as Map<String, dynamic>))
          .toList();
    } catch (_) {
      await (await SharedPreferences.getInstance()).remove(_savedRecipesKey);
      return const [];
    }
  }

  Future<void> saveSavedRecipes(List<Recipe> recipes) async {
    await (await SharedPreferences.getInstance()).setString(
      _savedRecipesKey,
      jsonEncode(recipes.map((recipe) => recipe.toJson()).toList()),
    );
  }

  Future<void> clearPrivateData() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
    await preferences.remove(_savedRecipesKey);
  }
}

class CookingProgress {
  const CookingProgress({
    required this.recipe,
    required this.step,
    required this.updatedAt,
    this.timerEndsAt,
  });

  final Recipe recipe;
  final int step;
  final DateTime updatedAt;
  final DateTime? timerEndsAt;

  CookingProgress copyWith(
          {int? step, DateTime? timerEndsAt, bool clearTimer = false}) =>
      CookingProgress(
        recipe: recipe,
        step: step ?? this.step,
        updatedAt: DateTime.now().toUtc(),
        timerEndsAt: clearTimer ? null : (timerEndsAt ?? this.timerEndsAt),
      );

  Map<String, dynamic> toJson() => {
        'recipe': recipe.toJson(),
        'step': step,
        'updated_at': updatedAt.toIso8601String(),
        'timer_ends_at': timerEndsAt?.toIso8601String(),
      };

  factory CookingProgress.fromJson(Map<String, dynamic> json) =>
      CookingProgress(
        recipe: Recipe.fromJson(json['recipe'] as Map<String, dynamic>),
        step: json['step'] as int? ?? 0,
        updatedAt: DateTime.parse(json['updated_at'] as String),
        timerEndsAt: json['timer_ends_at'] == null
            ? null
            : DateTime.parse(json['timer_ends_at'] as String),
      );
}
