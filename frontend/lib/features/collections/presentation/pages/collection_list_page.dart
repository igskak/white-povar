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
        appBar: AppBar(title: const Text('Колекції')),
        body: ref.watch(collectionListProvider).when(
              loading: () => const _CollectionListSkeleton(),
              error: (_, __) => StateView.error(
                title: 'Не вдалося завантажити колекції',
                subtitle: 'Перевірте з’єднання та спробуйте ще раз.',
                onRetry: () => ref.invalidate(collectionListProvider),
              ),
              data: (collections) => collections.isEmpty
                  ? const StateView.empty(
                      title: 'Колекції готуються',
                      subtitle: 'Нові матеріали автора з’являться тут згодом.',
                      icon: Icons.collections_bookmark_outlined,
                    )
                  : ResponsiveContainer(
                      maxWidth: 1180,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.sizeOf(context).width >= 1120
                                  ? 3
                                  : MediaQuery.sizeOf(context).width >= 700
                                      ? 2
                                      : 1,
                          mainAxisExtent:
                              MediaQuery.sizeOf(context).width >= 1024
                                  ? 220
                                  : 190,
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
                        ),
                        itemCount: collections.length,
                        itemBuilder: (_, index) => _CollectionCard(
                          collection: collections[index],
                          onTap: () => context
                              .push('/collections/${collections[index].id}'),
                        ),
                      ),
                    ),
            ),
      );
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection, required this.onTap});
  final ContentCollection collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ContentCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        semanticLabel: 'Відкрити колекцію ${collection.title}',
        child: Row(children: [
          SizedBox(
              width: MediaQuery.sizeOf(context).width >= 1024 ? 148 : 132,
              height: double.infinity,
              child: _Cover(url: collection.coverUrl)),
          Expanded(
              child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: AppSpacing.xs, children: [
                if (collection.isPremium)
                  const AppBadge(
                      label: 'Premium', icon: Icons.workspace_premium),
                if (collection.isLocked)
                  const AppBadge(label: 'Закрито', icon: Icons.lock_outline),
              ]),
              const SizedBox(height: AppSpacing.sm),
              Text(collection.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                  child: Text(collection.description,
                      maxLines: 2, overflow: TextOverflow.ellipsis)),
              Text('${collection.itemCount} матеріалів',
                  style: Theme.of(context).textTheme.labelMedium),
            ]),
          )),
        ]),
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
