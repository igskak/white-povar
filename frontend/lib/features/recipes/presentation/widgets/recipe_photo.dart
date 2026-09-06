import 'package:flutter/material.dart';

import '../../../../core/images/remote_image.dart';
import '../../models/recipe.dart';

/// Connects a recipe thumbnail to its detail hero without changing the image
/// source or access model. The transition disappears entirely when the user
/// asks the platform to reduce motion.
class RecipeImageHero extends StatelessWidget {
  const RecipeImageHero({
    super.key,
    required this.recipeId,
    required this.child,
    this.borderRadius = BorderRadius.zero,
  });

  final String recipeId;
  final Widget child;
  final BorderRadius borderRadius;

  static String tagFor(String recipeId) => 'recipe-image-$recipeId';

  @override
  Widget build(BuildContext context) {
    final frame = _RecipeImageHeroFrame(
      borderRadius: borderRadius,
      child: child,
    );
    if (MediaQuery.disableAnimationsOf(context)) return frame;

    return Hero(
      tag: tagFor(recipeId),
      transitionOnUserGestures: true,
      createRectTween: (begin, end) => MaterialRectCenterArcTween(
        begin: begin,
        end: end,
      ),
      flightShuttleBuilder: (
        _,
        animation,
        __,
        fromHeroContext,
        toHeroContext,
      ) {
        final from =
            (fromHeroContext.widget as Hero).child as _RecipeImageHeroFrame;
        final to =
            (toHeroContext.widget as Hero).child as _RecipeImageHeroFrame;
        final fade = CurvedAnimation(
          parent: animation,
          curve: const Interval(.18, .82, curve: Curves.easeInOut),
        );
        return AnimatedBuilder(
          animation: animation,
          builder: (_, __) => ClipRRect(
            borderRadius: BorderRadius.lerp(
              from.borderRadius,
              to.borderRadius,
              animation.value,
            )!,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(opacity: 1 - fade.value, child: from.child),
                Opacity(opacity: fade.value, child: to.child),
              ],
            ),
          ),
        );
      },
      child: frame,
    );
  }
}

class _RecipeImageHeroFrame extends StatelessWidget {
  const _RecipeImageHeroFrame({
    required this.borderRadius,
    required this.child,
  });

  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) => borderRadius == BorderRadius.zero
      ? child
      : ClipRRect(borderRadius: borderRadius, child: child);
}

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
