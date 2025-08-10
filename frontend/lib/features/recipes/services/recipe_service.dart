import '../models/recipe.dart';

class RecipeService {
  // TODO: Implement actual API calls to backend
  
  Future<List<Recipe>> getRecipes() async {
    // Mock data for now
    await Future.delayed(const Duration(seconds: 1));
    return [
      Recipe(
        id: '1',
        title: 'Mediterranean Pasta',
        description: 'A delicious pasta with sun-dried tomatoes and feta cheese',
        chefId: 'chef1',
        cuisine: 'Mediterranean',
        category: 'Dinner',
        difficulty: 2,
        prepTimeMinutes: 15,
        cookTimeMinutes: 20,
        totalTimeMinutes: 35,
        servings: 4,
        ingredients: [
          const Ingredient(
            id: '1',
            recipeId: '1',
            name: 'Pasta',
            amount: 12,
            unit: 'oz',
            order: 1,
          ),
          const Ingredient(
            id: '2',
            recipeId: '1',
            name: 'Sun-dried tomatoes',
            amount: 0.5,
            unit: 'cup',
            order: 2,
          ),
        ],
        instructions: [
          'Cook pasta according to package directions',
          'Heat olive oil in a large skillet',
          'Add garlic and sun-dried tomatoes',
          'Combine with pasta and serve'
        ],
        images: ['https://images.unsplash.com/photo-1621996346565-e3dbc353d2e5?w=800'],
        tags: ['pasta', 'mediterranean', 'quick'],
        isFeatured: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Recipe(
        id: '2',
        title: 'Spicy Chicken Tacos',
        description: 'Tender spiced chicken in warm tortillas with avocado crema',
        chefId: 'chef1',
        cuisine: 'Mexican',
        category: 'Dinner',
        difficulty: 3,
        prepTimeMinutes: 20,
        cookTimeMinutes: 25,
        totalTimeMinutes: 45,
        servings: 6,
        ingredients: [
          const Ingredient(
            id: '3',
            recipeId: '2',
            name: 'Chicken thighs',
            amount: 2,
            unit: 'lbs',
            order: 1,
          ),
          const Ingredient(
            id: '4',
            recipeId: '2',
            name: 'Corn tortillas',
            amount: 12,
            unit: 'pieces',
            order: 2,
          ),
        ],
        instructions: [
          'Season chicken with spices',
          'Cook chicken until done',
          'Prepare avocado crema',
          'Assemble tacos and serve'
        ],
        images: ['https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=800'],
        tags: ['tacos', 'mexican', 'spicy'],
        isFeatured: false,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  Future<Recipe> getRecipe(String id) async {
    final recipes = await getRecipes();
    return recipes.firstWhere((recipe) => recipe.id == id);
  }
}
