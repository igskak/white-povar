class IngredientSubstitution {
  final String substitute;
  final String explanation;
  final String ratio;

  const IngredientSubstitution({
    required this.substitute,
    required this.explanation,
    required this.ratio,
  });

  factory IngredientSubstitution.fromJson(Map<String, dynamic> json) {
    return IngredientSubstitution(
      substitute: json['substitute'] ?? '',
      explanation: json['explanation'] ?? '',
      ratio: json['ratio'] ?? '1:1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'substitute': substitute,
      'explanation': explanation,
      'ratio': ratio,
    };
  }
}

extension IngredientSubstitutionX on IngredientSubstitution {
  String get displayRatio {
    if (ratio == '1:1') {
      return 'Use same amount';
    }
    return 'Use $ratio ratio';
  }
}
