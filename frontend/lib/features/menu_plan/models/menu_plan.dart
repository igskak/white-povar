class MenuPlanSlot {
  const MenuPlanSlot(
      {required this.id,
      required this.plannedFor,
      required this.recipeId,
      required this.title,
      required this.servings,
      required this.position,
      this.collectionId,
      this.isPremium = false});
  final String id;
  final DateTime plannedFor;
  final String recipeId;
  final String? collectionId;
  final String title;
  final int servings;
  final int position;
  final bool isPremium;
  factory MenuPlanSlot.fromJson(Map<String, dynamic> json) => MenuPlanSlot(
      id: '${json['id']}',
      plannedFor: DateTime.parse('${json['planned_for']}'),
      recipeId: '${json['recipe_id']}',
      collectionId: json['collection_id']?.toString(),
      title: '${json['title']}',
      servings: (json['servings'] as num).toInt(),
      position: (json['position'] as num?)?.toInt() ?? 0,
      isPremium: json['is_premium'] == true);
  Map<String, dynamic> input() => {
        'planned_for': plannedFor.toIso8601String().substring(0, 10),
        'recipe_id': recipeId,
        'collection_id': collectionId,
        'servings': servings,
        'position': position
      };
  MenuPlanSlot copyWith({int? servings, int? position}) => MenuPlanSlot(
      id: id,
      plannedFor: plannedFor,
      recipeId: recipeId,
      collectionId: collectionId,
      title: title,
      servings: servings ?? this.servings,
      position: position ?? this.position,
      isPremium: isPremium);
}

class MenuPlanWeek {
  const MenuPlanWeek({required this.weekStart, required this.slots});
  final DateTime weekStart;
  final List<MenuPlanSlot> slots;
  factory MenuPlanWeek.fromJson(Map<String, dynamic> json) => MenuPlanWeek(
      weekStart: DateTime.parse('${json['week_start']}'),
      slots: (json['slots'] as List<dynamic>? ?? const [])
          .map((e) => MenuPlanSlot.fromJson(e as Map<String, dynamic>))
          .toList());
}
