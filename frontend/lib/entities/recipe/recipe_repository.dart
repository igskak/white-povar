import 'recipe.dart';

abstract interface class RecipeRepositoryV2 {
  Future<List<RecipeEntity>> getRecipes();
}
