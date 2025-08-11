class SearchFilters {
  final String? query;
  final String? cuisine;
  final String? category;
  final int? difficulty;
  final int? maxPrepTime;
  final int? maxCookTime;
  final int? maxTotalTime;
  final List<String>? dietaryRestrictions;
  final List<String>? ingredients;
  final String? chefId;
  final bool? isFeatured;
  final List<String>? tags;
  final int? minServings;
  final int? maxServings;
  final String sortBy;
  final String sortOrder;

  const SearchFilters({
    this.query,
    this.cuisine,
    this.category,
    this.difficulty,
    this.maxPrepTime,
    this.maxCookTime,
    this.maxTotalTime,
    this.dietaryRestrictions,
    this.ingredients,
    this.chefId,
    this.isFeatured,
    this.tags,
    this.minServings,
    this.maxServings,
    this.sortBy = 'created_at',
    this.sortOrder = 'desc',
  });

  SearchFilters copyWith({
    String? query,
    String? cuisine,
    String? category,
    int? difficulty,
    int? maxPrepTime,
    int? maxCookTime,
    int? maxTotalTime,
    List<String>? dietaryRestrictions,
    List<String>? ingredients,
    String? chefId,
    bool? isFeatured,
    List<String>? tags,
    int? minServings,
    int? maxServings,
    String? sortBy,
    String? sortOrder,
  }) {
    return SearchFilters(
      query: query ?? this.query,
      cuisine: cuisine ?? this.cuisine,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      maxPrepTime: maxPrepTime ?? this.maxPrepTime,
      maxCookTime: maxCookTime ?? this.maxCookTime,
      maxTotalTime: maxTotalTime ?? this.maxTotalTime,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      ingredients: ingredients ?? this.ingredients,
      chefId: chefId ?? this.chefId,
      isFeatured: isFeatured ?? this.isFeatured,
      tags: tags ?? this.tags,
      minServings: minServings ?? this.minServings,
      maxServings: maxServings ?? this.maxServings,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    
    if (query != null) data['query'] = query;
    if (cuisine != null) data['cuisine'] = cuisine;
    if (category != null) data['category'] = category;
    if (difficulty != null) data['difficulty'] = difficulty;
    if (maxPrepTime != null) data['max_prep_time'] = maxPrepTime;
    if (maxCookTime != null) data['max_cook_time'] = maxCookTime;
    if (maxTotalTime != null) data['max_total_time'] = maxTotalTime;
    if (dietaryRestrictions != null) data['dietary_restrictions'] = dietaryRestrictions;
    if (ingredients != null) data['ingredients'] = ingredients;
    if (chefId != null) data['chef_id'] = chefId;
    if (isFeatured != null) data['is_featured'] = isFeatured;
    if (tags != null) data['tags'] = tags;
    if (minServings != null) data['min_servings'] = minServings;
    if (maxServings != null) data['max_servings'] = maxServings;
    data['sort_by'] = sortBy;
    data['sort_order'] = sortOrder;
    
    return data;
  }

  factory SearchFilters.fromJson(Map<String, dynamic> json) {
    return SearchFilters(
      query: json['query'],
      cuisine: json['cuisine'],
      category: json['category'],
      difficulty: json['difficulty'],
      maxPrepTime: json['max_prep_time'],
      maxCookTime: json['max_cook_time'],
      maxTotalTime: json['max_total_time'],
      dietaryRestrictions: json['dietary_restrictions'] != null 
          ? List<String>.from(json['dietary_restrictions'])
          : null,
      ingredients: json['ingredients'] != null 
          ? List<String>.from(json['ingredients'])
          : null,
      chefId: json['chef_id'],
      isFeatured: json['is_featured'],
      tags: json['tags'] != null 
          ? List<String>.from(json['tags'])
          : null,
      minServings: json['min_servings'],
      maxServings: json['max_servings'],
      sortBy: json['sort_by'] ?? 'created_at',
      sortOrder: json['sort_order'] ?? 'desc',
    );
  }

  bool get isEmpty {
    return query == null &&
        cuisine == null &&
        category == null &&
        difficulty == null &&
        maxPrepTime == null &&
        maxCookTime == null &&
        maxTotalTime == null &&
        (dietaryRestrictions?.isEmpty ?? true) &&
        (ingredients?.isEmpty ?? true) &&
        chefId == null &&
        isFeatured == null &&
        (tags?.isEmpty ?? true) &&
        minServings == null &&
        maxServings == null;
  }

  int get activeFiltersCount {
    int count = 0;
    if (query != null && query!.isNotEmpty) count++;
    if (cuisine != null) count++;
    if (category != null) count++;
    if (difficulty != null) count++;
    if (maxPrepTime != null) count++;
    if (maxCookTime != null) count++;
    if (maxTotalTime != null) count++;
    if (dietaryRestrictions?.isNotEmpty ?? false) count++;
    if (ingredients?.isNotEmpty ?? false) count++;
    if (chefId != null) count++;
    if (isFeatured != null) count++;
    if (tags?.isNotEmpty ?? false) count++;
    if (minServings != null) count++;
    if (maxServings != null) count++;
    return count;
  }

  SearchFilters clear() {
    return const SearchFilters();
  }
}
