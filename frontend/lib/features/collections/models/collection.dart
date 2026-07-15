import 'package:equatable/equatable.dart';

import '../../recipes/models/recipe.dart';

class ContentCollection extends Equatable {
  const ContentCollection({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.itemCount,
    this.coverUrl,
    this.isPremium = false,
    this.isLocked = false,
    this.items = const [],
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final String? coverUrl;
  final bool isPremium;
  final bool isLocked;
  final int itemCount;
  final List<CollectionItem> items;

  factory ContentCollection.fromJson(Map<String, dynamic> json) =>
      ContentCollection(
        id: json['id'].toString(),
        slug: json['slug']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        coverUrl: json['cover_url']?.toString(),
        isPremium: json['is_premium'] == true,
        isLocked: json['is_locked'] == true,
        itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
        items: (json['items'] as List<dynamic>? ?? const [])
            .map(
                (item) => CollectionItem.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [
        id,
        slug,
        title,
        description,
        coverUrl,
        isPremium,
        isLocked,
        itemCount,
        items
      ];
}

class CollectionItem extends Equatable {
  const CollectionItem({
    required this.id,
    required this.position,
    required this.content,
    this.isPreview = false,
  });

  final String id;
  final int position;
  final bool isPreview;
  final Recipe content;

  bool get isLocked => content.isLocked;

  factory CollectionItem.fromJson(Map<String, dynamic> json) => CollectionItem(
        id: json['id'].toString(),
        position: (json['position'] as num?)?.toInt() ?? 0,
        isPreview: json['is_preview'] == true,
        content: Recipe.fromJson(json['content'] as Map<String, dynamic>),
      );

  @override
  List<Object?> get props => [id, position, isPreview, content];
}
