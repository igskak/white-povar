import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/state_views.dart';
import '../../models/collection.dart';
import '../../providers/collection_provider.dart';

class CollectionListPage extends ConsumerWidget {
  const CollectionListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const ResponsiveContainer(
                maxWidth: 1180,
                child: _CollectionPageIntro(),
              ),
              Expanded(
                child: ref.watch(collectionListProvider).when(
                      loading: () => const _CollectionListSkeleton(),
                      error: (_, __) => StateView.error(
                        title: 'Не вдалося завантажити колекції',
                        subtitle: 'Перевірте з’єднання та спробуйте ще раз.',
                        onRetry: () => ref.invalidate(collectionListProvider),
                      ),
                      data: (collections) => collections.isEmpty
                          ? const StateView.empty(
                              title: 'Колекції готуються',
                              subtitle:
                                  'Нові матеріали автора з’являться тут згодом.',
                              icon: Icons.collections_bookmark_outlined,
                            )
                          : ResponsiveContainer(
                              maxWidth: 1180,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final columns = constraints.maxWidth >= 1024
                                      ? 3
                                      : constraints.maxWidth >= 600
                                          ? 2
                                          : 1;
                                  return GridView.builder(
                                    key: const ValueKey(
                                        'collections-responsive-grid'),
                                    padding:
                                        const EdgeInsets.all(AppSpacing.md),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisExtent: columns == 1 ? 190 : 320,
                                      crossAxisSpacing: AppSpacing.md,
                                      mainAxisSpacing: AppSpacing.md,
                                    ),
                                    itemCount: collections.length,
                                    itemBuilder: (_, index) => _CollectionCard(
                                      collection: collections[index],
                                      vertical: columns > 1,
                                      onTap: () => context.push(
                                          '/collections/${collections[index].id}'),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
              ),
            ],
          ),
        ),
      );
}

class _CollectionPageIntro extends StatelessWidget {
  const _CollectionPageIntro();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Колекції', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Авторські добірки рецептів, технік і процесів.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColorsV2.textSecondary),
            ),
          ],
        ),
      );
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.collection,
    required this.vertical,
    required this.onTap,
  });
  final ContentCollection collection;
  final bool vertical;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ContentCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        semanticLabel: 'Відкрити колекцію ${collection.title}',
        child: vertical
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _Cover(url: collection.coverUrl)),
                  SizedBox(
                    height: 142,
                    child: _CollectionCardBody(collection: collection),
                  ),
                ],
              )
            : Row(children: [
                SizedBox(
                  width: 132,
                  height: double.infinity,
                  child: _Cover(url: collection.coverUrl),
                ),
                Expanded(child: _CollectionCardBody(collection: collection)),
              ]),
      );
}

class _CollectionCardBody extends StatelessWidget {
  const _CollectionCardBody({required this.collection});

  final ContentCollection collection;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: AppSpacing.xs, children: [
              if (collection.isPremium)
                const AppBadge(label: 'Premium', icon: Icons.workspace_premium),
              if (collection.isLocked)
                const AppBadge(label: 'Закрито', icon: Icons.lock_outline),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Text(
              collection.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            Text(
              '${collection.itemCount} матеріалів',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      );
}

class _Cover extends StatelessWidget {
  const _Cover({this.url});
  final String? url;
  @override
  Widget build(BuildContext context) => url == null || url!.isEmpty
      ? const _CoverFallback()
      : CachedNetworkImage(
          imageUrl: url!,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => const _CoverFallback());
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();
  @override
  Widget build(BuildContext context) => Container(
        color: AppColorsV2.surfaceStrong,
        alignment: Alignment.center,
        child: const Icon(Icons.collections_bookmark_outlined, size: 42),
      );
}

class _CollectionListSkeleton extends StatelessWidget {
  const _CollectionListSkeleton();
  @override
  Widget build(BuildContext context) => const ResponsiveContainer(
        maxWidth: 1040,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(children: [
            AppSkeleton(height: 190),
            SizedBox(height: AppSpacing.md),
            AppSkeleton(height: 190)
          ]),
        ),
      );
}
