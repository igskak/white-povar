import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';

/// Shared save control for every recipe presentation.
///
/// Guests are sent through login with their intended save retained by the
/// canonical favorite notifier; authenticated changes are optimistic and offer
/// a short undo affordance.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.recipeId, this.color});

  final String recipeId;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(currentUserProvider) != null;
    final saved = signedIn
        ? ref.watch(
            favoriteIdsProvider.select(
              (recipeIds) => recipeIds.contains(recipeId),
            ),
          )
        : false;

    return IconButton(
      tooltip: saved ? 'Прибрати зі збереженого' : 'Зберегти рецепт',
      onPressed: () => _toggle(context, ref, signedIn, saved),
      icon: Icon(
        saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        color: color,
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    bool signedIn,
    bool saved,
  ) async {
    final favorites = ref.read(favoriteIdsProvider.notifier);
    if (!signedIn) {
      await favorites.queueGuestIntent(recipeId);
      if (!context.mounted) return;
      final returnTo = GoRouterState.of(context).uri.toString();
      context.go('/login?returnTo=${Uri.encodeComponent(returnTo)}');
      return;
    }

    final shouldSave = !saved;
    try {
      await favorites.setFavorite(recipeId, shouldSave);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(shouldSave ? 'Рецепт збережено' : 'Рецепт прибрано'),
          action: SnackBarAction(
            label: 'Скасувати',
            onPressed: () => favorites.setFavorite(recipeId, saved),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося оновити збережене')),
      );
    }
  }
}
