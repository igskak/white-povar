class GeneratedRecipe {
  const GeneratedRecipe({
    required this.title,
    required this.description,
    required this.servings,
    required this.totalTimeMinutes,
    required this.ingredients,
    required this.steps,
    required this.safetyNote,
    required this.attribution,
  });

  final String title;
  final String description;
  final int servings;
  final int totalTimeMinutes;
  final List<GeneratedIngredient> ingredients;
  final List<String> steps;
  final String safetyNote;
  final String attribution;

  factory GeneratedRecipe.fromJson(Map<String, dynamic> json) =>
      GeneratedRecipe(
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        servings: (json['servings'] as num?)?.toInt() ?? 1,
        totalTimeMinutes: (json['total_time_minutes'] as num?)?.toInt() ?? 0,
        ingredients: (json['ingredients'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(GeneratedIngredient.fromJson)
            .toList(),
        steps: (json['steps'] as List<dynamic>? ?? [])
            .map((value) => value.toString())
            .toList(),
        safetyNote: json['safety_note']?.toString() ?? '',
        attribution: json['attribution']?.toString() ??
            'Створено AI, не опублікований рецепт автора',
      );

  Map<String, dynamic> toJson() => {
        'source': 'ai_generated',
        'title': title,
        'description': description,
        'servings': servings,
        'total_time_minutes': totalTimeMinutes,
        'ingredients': ingredients
            .map((item) => {'name': item.name, 'amount': item.amount})
            .toList(),
        'steps': steps,
        'safety_note': safetyNote,
        'attribution': attribution,
      };
}

class GeneratedIngredient {
  const GeneratedIngredient({required this.name, required this.amount});
  final String name;
  final String amount;
  factory GeneratedIngredient.fromJson(Map<String, dynamic> json) =>
      GeneratedIngredient(
        name: json['name']?.toString() ?? '',
        amount: json['amount']?.toString() ?? '',
      );
}
