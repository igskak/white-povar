class PantryItem {
  const PantryItem(
      {required this.id,
      required this.name,
      this.quantity,
      this.unit,
      this.freshnessDate,
      this.source = 'manual',
      this.confidence});
  final String id;
  final String name;
  final double? quantity;
  final String? unit;
  final DateTime? freshnessDate;
  final String source;
  final double? confidence;
  factory PantryItem.fromJson(Map<String, dynamic> json) => PantryItem(
      id: '${json['id']}',
      name: '${json['name']}',
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      freshnessDate: json['freshness_date'] == null
          ? null
          : DateTime.tryParse('${json['freshness_date']}'),
      source: '${json['source'] ?? 'manual'}',
      confidence: (json['confidence'] as num?)?.toDouble());
  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'freshness_date': freshnessDate?.toIso8601String(),
        'source': source,
        'confidence': confidence,
        'confirmed': true
      };
}

class ShoppingItem {
  const ShoppingItem(
      {required this.id,
      required this.name,
      this.quantity,
      this.unit,
      required this.category,
      this.checked = false,
      this.recipeId});
  final String id;
  final String name;
  final double? quantity;
  final String? unit;
  final String category;
  final bool checked;
  final String? recipeId;
  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
      id: '${json['id']}',
      name: '${json['name']}',
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      category: '${json['category'] ?? 'Інше'}',
      checked: json['checked'] == true,
      recipeId: json['recipe_id'] as String?);
  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'category': category,
        'recipe_id': recipeId,
        'checked': checked
      };
  ShoppingItem copyWith({bool? checked}) => ShoppingItem(
      id: id,
      name: name,
      quantity: quantity,
      unit: unit,
      category: category,
      checked: checked ?? this.checked,
      recipeId: recipeId);
}
