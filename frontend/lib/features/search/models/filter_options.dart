class FilterOptions {
  final List<String> cuisines;
  final List<String> categories;
  final RangeOption difficultyRange;
  final TimeRanges timeRanges;
  final RangeOption servingsRange;
  final List<String> popularTags;
  final List<String> dietaryRestrictions;

  const FilterOptions({
    required this.cuisines,
    required this.categories,
    required this.difficultyRange,
    required this.timeRanges,
    required this.servingsRange,
    required this.popularTags,
    required this.dietaryRestrictions,
  });

  factory FilterOptions.fromJson(Map<String, dynamic> json) {
    return FilterOptions(
      cuisines: List<String>.from(json['cuisines'] ?? []),
      categories: List<String>.from(json['categories'] ?? []),
      difficultyRange: RangeOption.fromJson(json['difficulty_range'] ?? {}),
      timeRanges: TimeRanges.fromJson(json['time_ranges'] ?? {}),
      servingsRange: RangeOption.fromJson(json['servings_range'] ?? {}),
      popularTags: List<String>.from(json['popular_tags'] ?? []),
      dietaryRestrictions: List<String>.from(json['dietary_restrictions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cuisines': cuisines,
      'categories': categories,
      'difficulty_range': difficultyRange.toJson(),
      'time_ranges': timeRanges.toJson(),
      'servings_range': servingsRange.toJson(),
      'popular_tags': popularTags,
      'dietary_restrictions': dietaryRestrictions,
    };
  }
}

class RangeOption {
  final int min;
  final int max;

  const RangeOption({
    required this.min,
    required this.max,
  });

  factory RangeOption.fromJson(Map<String, dynamic> json) {
    return RangeOption(
      min: json['min'] ?? 0,
      max: json['max'] ?? 100,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'min': min,
      'max': max,
    };
  }
}

class TimeRanges {
  final RangeOption prepTime;
  final RangeOption cookTime;
  final RangeOption totalTime;

  const TimeRanges({
    required this.prepTime,
    required this.cookTime,
    required this.totalTime,
  });

  factory TimeRanges.fromJson(Map<String, dynamic> json) {
    return TimeRanges(
      prepTime: RangeOption.fromJson(json['prep_time'] ?? {}),
      cookTime: RangeOption.fromJson(json['cook_time'] ?? {}),
      totalTime: RangeOption.fromJson(json['total_time'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'prep_time': prepTime.toJson(),
      'cook_time': cookTime.toJson(),
      'total_time': totalTime.toJson(),
    };
  }
}
