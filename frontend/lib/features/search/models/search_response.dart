import '../../recipes/models/recipe.dart';

class SearchResponse {
  final List<Recipe> recipes;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;
  final Map<String, dynamic> filtersApplied;

  const SearchResponse({
    required this.recipes,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
    required this.filtersApplied,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      recipes: (json['recipes'] as List<dynamic>)
          .map((recipeJson) => Recipe.fromJson(recipeJson))
          .toList(),
      totalCount: json['total_count'] ?? 0,
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? 20,
      totalPages: json['total_pages'] ?? 1,
      hasNext: json['has_next'] ?? false,
      hasPrev: json['has_prev'] ?? false,
      filtersApplied: Map<String, dynamic>.from(json['filters_applied'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recipes': recipes.map((recipe) => recipe.toJson()).toList(),
      'total_count': totalCount,
      'page': page,
      'page_size': pageSize,
      'total_pages': totalPages,
      'has_next': hasNext,
      'has_prev': hasPrev,
      'filters_applied': filtersApplied,
    };
  }

  bool get isEmpty => recipes.isEmpty;
  bool get isNotEmpty => recipes.isNotEmpty;
}
