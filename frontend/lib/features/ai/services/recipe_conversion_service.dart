import '../models/recipe_suggestion.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/services/recipe_service.dart';

class RecipeConversionService {
  static RecipeConversionService? _instance;
  static RecipeConversionService get instance =>
      _instance ??= RecipeConversionService._();

  RecipeConversionService._();

  final RecipeService _recipeService = RecipeService();

  /// Convert AI suggestion to full Recipe and save it
  Future<Recipe> saveAISuggestionAsRecipe(
      RecipeSuggestion suggestion, List<String> availableIngredients) async {
    try {
      // Convert AI suggestion to Recipe format
      final recipe = Recipe(
        id: '', // Will be set by backend
        title: suggestion.title,
        description: suggestion.description,
        chefId: '', // Will be set by backend
        cuisine: _extractCuisine(suggestion.description),
        category: 'AI Generated',
        difficulty: _mapDifficultyToInt(suggestion.difficulty),
        prepTimeMinutes: suggestion.prepTime,
        cookTimeMinutes: suggestion.cookTime,
        totalTimeMinutes: suggestion.prepTime + suggestion.cookTime,
        servings: 4, // Default servings
        ingredients: _buildIngredientsObjects(suggestion, availableIngredients),
        instructions: _buildInstructionsList(suggestion),
        images: const [], // No images for AI suggestions initially
        tags: _buildTags(suggestion),
        isFeatured: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save via RecipeService
      final savedRecipe = await _recipeService.createRecipe(recipe);
      return savedRecipe;
    } catch (e) {
      throw Exception('Failed to save AI suggestion as recipe: $e');
    }
  }

  /// Generate organized shopping list from missing ingredients
  Map<String, dynamic> generateShoppingList(RecipeSuggestion suggestion) {
    final categorizedIngredients = <String, List<Map<String, dynamic>>>{};

    // Categorize each missing ingredient
    for (final ingredient in suggestion.missingIngredients) {
      final category = _categorizeIngredient(ingredient);
      final ingredientData = {
        'name': ingredient,
        'estimated_amount': _estimateAmount(ingredient),
        'priority': _determinePriority(ingredient),
        'estimated_cost': _estimateCost(ingredient),
      };

      if (categorizedIngredients.containsKey(category)) {
        categorizedIngredients[category]!.add(ingredientData);
      } else {
        categorizedIngredients[category] = [ingredientData];
      }
    }

    // Calculate totals
    final totalItems = suggestion.missingIngredients.length;
    final estimatedTotalCost = totalItems * 3.50; // Average $3.50 per item

    return {
      'recipe_title': suggestion.title,
      'recipe_description': suggestion.description,
      'total_items': totalItems,
      'categorized_ingredients': categorizedIngredients,
      'estimated_total_cost': '\$${estimatedTotalCost.toStringAsFixed(2)}',
      'prep_time_impact': totalItems > 5
          ? 'high'
          : totalItems > 2
              ? 'medium'
              : 'low',
      'shopping_tips': _generateShoppingTips(categorizedIngredients),
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Map difficulty string to integer
  int _mapDifficultyToInt(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 1;
      case 'medium':
        return 2;
      case 'hard':
        return 3;
      default:
        return 2; // Default to medium
    }
  }

  /// Build ingredients objects for Recipe model
  List<Ingredient> _buildIngredientsObjects(
      RecipeSuggestion suggestion, List<String> availableIngredients) {
    final ingredients = <Ingredient>[];
    int order = 0;

    // Add available ingredients
    for (final ingredient in availableIngredients) {
      ingredients.add(Ingredient(
        id: '', // Will be set by backend
        recipeId: '', // Will be set by backend
        name: ingredient,
        amount: _parseAmount(_estimateAmount(ingredient)),
        unit: _parseUnit(_estimateAmount(ingredient)),
        notes: 'Available ingredient',
        order: order++,
      ));
    }

    // Add missing ingredients
    for (final ingredient in suggestion.missingIngredients) {
      ingredients.add(Ingredient(
        id: '', // Will be set by backend
        recipeId: '', // Will be set by backend
        name: ingredient,
        amount: _parseAmount(_estimateAmount(ingredient)),
        unit: _parseUnit(_estimateAmount(ingredient)),
        notes: 'Missing ingredient',
        order: order++,
      ));
    }

    return ingredients;
  }

  /// Parse amount from estimated amount string
  double _parseAmount(String estimatedAmount) {
    final parts = estimatedAmount.split(' ');
    if (parts.isNotEmpty) {
      // Try to parse the first part as a number
      final numberPart = parts[0];
      if (numberPart.contains('/')) {
        // Handle fractions like "1/2"
        final fractionParts = numberPart.split('/');
        if (fractionParts.length == 2) {
          final numerator = double.tryParse(fractionParts[0]) ?? 1;
          final denominator = double.tryParse(fractionParts[1]) ?? 1;
          return numerator / denominator;
        }
      }
      return double.tryParse(numberPart) ?? 1.0;
    }
    return 1.0;
  }

  /// Parse unit from estimated amount string
  String _parseUnit(String estimatedAmount) {
    final parts = estimatedAmount.split(' ');
    if (parts.length > 1) {
      return parts.sublist(1).join(' ');
    }
    return 'piece';
  }

  /// Extract cuisine type from description
  String _extractCuisine(String description) {
    final lower = description.toLowerCase();
    if (lower.contains('italian') ||
        lower.contains('pasta') ||
        lower.contains('pizza')) {
      return 'Italian';
    } else if (lower.contains('mexican') ||
        lower.contains('taco') ||
        lower.contains('salsa')) {
      return 'Mexican';
    } else if (lower.contains('asian') ||
        lower.contains('chinese') ||
        lower.contains('thai')) {
      return 'Asian';
    } else if (lower.contains('mediterranean') || lower.contains('greek')) {
      return 'Mediterranean';
    } else if (lower.contains('indian') || lower.contains('curry')) {
      return 'Indian';
    }
    return 'International';
  }

  /// Build basic instructions list
  List<String> _buildInstructionsList(RecipeSuggestion suggestion) {
    // Generate basic instructions based on suggestion
    return [
      'Gather all ingredients and prepare your workspace.',
      'Follow the cooking techniques suggested for this ${suggestion.difficulty.toLowerCase()} recipe.',
      'Cook according to the estimated prep time of ${suggestion.prepTime} minutes and cook time of ${suggestion.cookTime} minutes.',
      'Adjust seasoning to taste and serve hot.',
      'Enjoy your AI-generated ${suggestion.title}!',
    ];
  }

  /// Build tags from suggestion
  List<String> _buildTags(RecipeSuggestion suggestion) {
    final tags = <String>['AI Generated', suggestion.difficulty];

    // Add time-based tags
    if (suggestion.prepTime + suggestion.cookTime <= 30) {
      tags.add('Quick');
    }
    if (suggestion.prepTime <= 15) {
      tags.add('Easy Prep');
    }

    return tags;
  }

  /// Categorize ingredient for shopping organization
  String _categorizeIngredient(String ingredient) {
    final lower = ingredient.toLowerCase();

    if (lower.contains('meat') ||
        lower.contains('chicken') ||
        lower.contains('beef') ||
        lower.contains('pork') ||
        lower.contains('fish') ||
        lower.contains('salmon') ||
        lower.contains('turkey') ||
        lower.contains('lamb')) {
      return 'Meat & Seafood';
    } else if (lower.contains('milk') ||
        lower.contains('cheese') ||
        lower.contains('yogurt') ||
        lower.contains('butter') ||
        lower.contains('cream') ||
        lower.contains('egg')) {
      return 'Dairy & Eggs';
    } else if (lower.contains('apple') ||
        lower.contains('banana') ||
        lower.contains('orange') ||
        lower.contains('berry') ||
        lower.contains('fruit') ||
        lower.contains('lemon') ||
        lower.contains('lime') ||
        lower.contains('grape')) {
      return 'Fruits';
    } else if (lower.contains('lettuce') ||
        lower.contains('tomato') ||
        lower.contains('onion') ||
        lower.contains('carrot') ||
        lower.contains('pepper') ||
        lower.contains('vegetable') ||
        lower.contains('spinach') ||
        lower.contains('broccoli') ||
        lower.contains('potato')) {
      return 'Vegetables';
    } else if (lower.contains('bread') ||
        lower.contains('pasta') ||
        lower.contains('rice') ||
        lower.contains('flour') ||
        lower.contains('cereal') ||
        lower.contains('grain')) {
      return 'Grains & Bread';
    } else if (lower.contains('oil') ||
        lower.contains('vinegar') ||
        lower.contains('salt') ||
        lower.contains('pepper') ||
        lower.contains('spice') ||
        lower.contains('herb') ||
        lower.contains('sauce') ||
        lower.contains('dressing')) {
      return 'Condiments & Spices';
    } else if (lower.contains('bean') ||
        lower.contains('lentil') ||
        lower.contains('nut') ||
        lower.contains('seed') ||
        lower.contains('tofu')) {
      return 'Pantry & Protein';
    } else {
      return 'Other';
    }
  }

  /// Estimate amount for ingredient
  String _estimateAmount(String ingredient) {
    final lower = ingredient.toLowerCase();

    if (lower.contains('salt') ||
        lower.contains('pepper') ||
        lower.contains('spice')) {
      return '1 tsp';
    } else if (lower.contains('oil') || lower.contains('vinegar')) {
      return '2 tbsp';
    } else if (lower.contains('onion') || lower.contains('tomato')) {
      return '1 medium';
    } else if (lower.contains('meat') ||
        lower.contains('chicken') ||
        lower.contains('fish')) {
      return '1 lb';
    } else if (lower.contains('milk') || lower.contains('cream')) {
      return '1 cup';
    } else if (lower.contains('cheese')) {
      return '1/2 cup';
    } else {
      return '1 piece';
    }
  }

  /// Determine shopping priority
  String _determinePriority(String ingredient) {
    final lower = ingredient.toLowerCase();

    if (lower.contains('meat') ||
        lower.contains('fish') ||
        lower.contains('milk') ||
        lower.contains('egg')) {
      return 'high'; // Perishables
    } else if (lower.contains('vegetable') || lower.contains('fruit')) {
      return 'medium'; // Fresh produce
    } else {
      return 'low'; // Pantry items
    }
  }

  /// Estimate cost for ingredient
  String _estimateCost(String ingredient) {
    final lower = ingredient.toLowerCase();

    if (lower.contains('meat') ||
        lower.contains('fish') ||
        lower.contains('seafood')) {
      return '\$8-12';
    } else if (lower.contains('cheese') || lower.contains('nuts')) {
      return '\$4-6';
    } else if (lower.contains('vegetable') || lower.contains('fruit')) {
      return '\$2-4';
    } else {
      return '\$1-3';
    }
  }

  /// Generate helpful shopping tips
  List<String> _generateShoppingTips(
      Map<String, List<Map<String, dynamic>>> categorizedIngredients) {
    final tips = <String>[];

    if (categorizedIngredients.containsKey('Meat & Seafood')) {
      tips.add('🥩 Visit the meat counter first for freshest selection');
    }
    if (categorizedIngredients.containsKey('Fruits') ||
        categorizedIngredients.containsKey('Vegetables')) {
      tips.add('🥬 Check produce for ripeness and seasonal availability');
    }
    if (categorizedIngredients.containsKey('Dairy & Eggs')) {
      tips.add('🥛 Check expiration dates on dairy products');
    }
    if (categorizedIngredients.length > 3) {
      tips.add('🛒 Consider shopping the perimeter of the store first');
    }

    return tips;
  }
}
