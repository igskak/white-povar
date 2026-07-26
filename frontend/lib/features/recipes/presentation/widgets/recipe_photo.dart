import 'package:flutter/material.dart';

import '../../../../core/images/remote_image.dart';
import '../../models/recipe.dart';

/// One role-aware recipe image renderer shared by every consumer surface.
class RecipePhoto extends StatelessWidget {
  const RecipePhoto({
    super.key,
    required this.recipe,
    this.role = RecipeImageRole.primary,
    this.width,
    this.height,
    this.targetWidth,
    this.borderRadius = BorderRadius.zero,
  });

  final Recipe recipe;
  final RecipeImageRole role;
  final double? width;
  final double? height;
  final double? targetWidth;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final source = recipe.imageFor(role);
    final fallback = _RecipePhotoFallback(
      isLoading: source != null,
    );
    final content = source == null
        ? const _RecipePhotoFallback()
        : Semantics(
            image: true,
            label: source.altText.isEmpty ? recipe.title : source.altText,
            child: RemoteImage(
              url: source.url,
              targetWidth: targetWidth ?? width ?? 400,
              alignment: Alignment(
                source.focal.x * 2 - 1,
                source.focal.y * 2 - 1,
              ),
              placeholder: fallback,
              errorWidget: const _RecipePhotoFallback(),
            ),
          );
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(width: width, height: height, child: content),
    );
  }
}

class _RecipePhotoFallback extends StatelessWidget {
  const _RecipePhotoFallback({this.isLoading = false});

  final bool isLoading;

  @override
  Widget build(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Icon(
                Icons.restaurant_menu_rounded,
                size: 44,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
      );
}
