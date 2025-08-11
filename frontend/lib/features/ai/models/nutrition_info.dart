import 'package:flutter/material.dart';

class NutritionInfo {
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sugarG;
  final double sodiumMg;
  final String notes;

  const NutritionInfo({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.sugarG,
    required this.sodiumMg,
    required this.notes,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      calories: (json['calories'] ?? 0).toDouble(),
      proteinG: (json['protein_g'] ?? 0).toDouble(),
      carbsG: (json['carbs_g'] ?? 0).toDouble(),
      fatG: (json['fat_g'] ?? 0).toDouble(),
      fiberG: (json['fiber_g'] ?? 0).toDouble(),
      sugarG: (json['sugar_g'] ?? 0).toDouble(),
      sodiumMg: (json['sodium_mg'] ?? 0).toDouble(),
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'fiber_g': fiberG,
      'sugar_g': sugarG,
      'sodium_mg': sodiumMg,
      'notes': notes,
    };
  }
}

extension NutritionInfoX on NutritionInfo {
  String get caloriesDisplay => '${calories.round()} cal';

  String get proteinDisplay => '${proteinG.toStringAsFixed(1)}g protein';

  String get carbsDisplay => '${carbsG.toStringAsFixed(1)}g carbs';

  String get fatDisplay => '${fatG.toStringAsFixed(1)}g fat';

  String get fiberDisplay => '${fiberG.toStringAsFixed(1)}g fiber';

  String get sodiumDisplay => '${sodiumMg.round()}mg sodium';

  List<Map<String, dynamic>> get macroBreakdown => [
        {
          'name': 'Protein',
          'value': proteinG,
          'percentage': (proteinG * 4 / calories * 100).round(),
          'color': const Color(0xFF4CAF50),
        },
        {
          'name': 'Carbs',
          'value': carbsG,
          'percentage': (carbsG * 4 / calories * 100).round(),
          'color': const Color(0xFF2196F3),
        },
        {
          'name': 'Fat',
          'value': fatG,
          'percentage': (fatG * 9 / calories * 100).round(),
          'color': const Color(0xFFFF9800),
        },
      ];
}
