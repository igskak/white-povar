class RecipeSuggestion {
  final String title;
  final String description;
  final int prepTime;
  final int cookTime;
  final String difficulty;
  final List<String> missingIngredients;
  final List<String> keyTechniques;

  const RecipeSuggestion({
    required this.title,
    required this.description,
    required this.prepTime,
    required this.cookTime,
    required this.difficulty,
    required this.missingIngredients,
    required this.keyTechniques,
  });

  factory RecipeSuggestion.fromJson(Map<String, dynamic> json) {
    return RecipeSuggestion(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      prepTime: json['prep_time'] ?? 0,
      cookTime: json['cook_time'] ?? 0,
      difficulty: json['difficulty'] ?? '',
      missingIngredients: List<String>.from(json['missing_ingredients'] ?? []),
      keyTechniques: List<String>.from(json['key_techniques'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'prep_time': prepTime,
      'cook_time': cookTime,
      'difficulty': difficulty,
      'missing_ingredients': missingIngredients,
      'key_techniques': keyTechniques,
    };
  }
}

extension RecipeSuggestionX on RecipeSuggestion {
  int get totalTime => prepTime + cookTime;

  bool get hasAllIngredients => missingIngredients.isEmpty;

  String get difficultyDisplay {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 'Easy';
      case 'medium':
        return 'Medium';
      case 'hard':
        return 'Hard';
      default:
        return difficulty;
    }
  }

  String get timeDisplay {
    if (totalTime < 60) {
      return '${totalTime}min';
    } else {
      final hours = totalTime ~/ 60;
      final minutes = totalTime % 60;
      return minutes > 0 ? '${hours}h ${minutes}min' : '${hours}h';
    }
  }
}
