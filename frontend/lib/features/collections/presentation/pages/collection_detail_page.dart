import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_models.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/branding/brand_providers.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../menu_plan/providers/menu_plan_provider.dart';
import '../../../recipes/models/recipe.dart';
import '../../models/collection.dart';
import '../../providers/collection_provider.dart';
import '../../services/collection_resume_store.dart';

class CollectionDetailPage extends ConsumerStatefulWidget {
  const CollectionDetailPage({super.key, required this.collectionId});
  final String collectionId;

  @override
  ConsumerState<CollectionDetailPage> createState() =>
      _CollectionDetailPageState();
}

class _CollectionDetailPageState extends ConsumerState<CollectionDetailPage> {
  final _resumeStore = CollectionResumeStore();
  String? _resumeItemId;

  @override
  void initState() {
    super.initState();
    _resumeStore.read(widget.collectionId).then((id) {
      if (mounted) setState(() => _resumeItemId = id);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ref.watch(collectionDetailProvider(widget.collectionId)).when(
              loading: () => const _DetailSkeleton(),
              error: (_, __) => StateView.error(
                title: 'Не вдалося відкрити колекцію',
                subtitle: 'Можливо, вона більше недоступна.',
                onRetry: () => ref
                    .invalidate(collectionDetailProvider(widget.collectionId)),
              ),
              data: _buildDetail,
            ),
      );

  Widget _buildDetail(ContentCollection collection) {
    final brand = ref.watch(tenantBootstrapProvider).brandConfig.brand;
    final authenticated = ref.watch(currentUserProvider) != null;
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
          child: _CollectionHero(collection: collection, author: brand.name)),
      SliverToBoxAdapter(
          child: ResponsiveContainer(
        maxWidth: 1120,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.xxl),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (collection.isLocked) ...[
              _CollectionGate(onOpen: () => _openGate(authenticated)),
              const SizedBox(height: AppSpacing.xl),
            ],
            Text('Матеріали', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 2 : 1;
              return GridView.builder(
                key: const ValueKey('collection-items-grid'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: columns == 1 ? 142 : 168,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                ),
                itemCount: collection.items.length,
                itemBuilder: (context, index) {
                  final item = collection.items[index];
                  return _CollectionItemCard(
                    item: item,
                    isResume: item.id == _resumeItemId,
                    onTap: item.isLocked
                        ? () => _openGate(authenticated)
                        : () => _openItem(collection, item),
                    onPlan: item.isLocked || !authenticated
                        ? null
                        : () async {
                            await ref.read(menuPlanServiceProvider).add(
                                day: DateTime.now(),
                                recipeId: item.content.id,
                                collectionId: collection.id,
                                servings: item.content.servings);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Матеріал заплановано на сьогодні')));
                            }
                          },
                  );
                },
              );
            }),
          ]),
        ),
      )),
    ]);
  }

  void _openGate(bool authenticated) {
    final returnTo = '/collections/${widget.collectionId}';
    if (!authenticated) {
      context.go('/login?returnTo=${Uri.encodeComponent(returnTo)}');
    } else {
      context
          .push(OfferRouteLocation.subscription(returnTo: returnTo).location);
    }
  }

  Future<void> _openItem(
      ContentCollection collection, CollectionItem item) async {
    await _resumeStore.save(collection.id, item.id);
    if (mounted) setState(() => _resumeItemId = item.id);
    final path = switch (item.content.contentKind) {
      ContentKind.recipe => '/recipes/${item.content.id}',
      _ => '/content/${item.content.id}',
    };
    if (mounted) context.push(path);
  }
}

class _CollectionHero extends StatelessWidget {
  const _CollectionHero({required this.collection, required this.author});
  final ContentCollection collection;
  final String author;

  @override
  Widget build(BuildContext context) => SizedBox(
      height: MediaQuery.sizeOf(context).width >= 1024 ? 380 : 300,
      child: Stack(fit: StackFit.expand, children: [
        collection.coverUrl == null || collection.coverUrl!.isEmpty
            ? const _HeroFallback()
            : CachedNetworkImage(
                imageUrl: collection.coverUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const _HeroFallback()),
        DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
              AppColorsV2.ink.withOpacity(.20),
              AppColorsV2.ink.withOpacity(.90)
            ]))),
        Positioned(
            top: AppSpacing.md,
            left: AppSpacing.sm,
            child: AppIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Назад',
                onPressed: () => Navigator.of(context).maybePop(),
                filled: true)),
        Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (collection.isPremium)
                    const AppBadge(
                        label: 'Premium-колекція',
                        icon: Icons.workspace_premium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(collection.title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: AppColorsV2.onInk)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Від $author',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColorsV2.onInk)),
                ])),
      ]));
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();
  @override
  Widget build(BuildContext context) => Container(
      color: AppColorsV2.ink,
      alignment: Alignment.center,
      child: const Icon(Icons.collections_bookmark_outlined,
          color: AppColorsV2.onInk, size: 64));
}

class _CollectionGate extends StatelessWidget {
  const _CollectionGate({required this.onOpen});
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => ContentCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AppBadge(label: 'Закрита колекція', icon: Icons.lock_outline),
        const SizedBox(height: AppSpacing.sm),
        Text('Відкрийте повну майстерню',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        const Text(
            'Попередній перегляд доступний нижче. Решта матеріалів відкриються після підтвердження доступу.'),
        const SizedBox(height: AppSpacing.md),
        AppButton(
            label: 'Переглянути доступ',
            icon: Icons.workspace_premium,
            onPressed: onOpen),
      ]));
}

class _CollectionItemCard extends StatelessWidget {
  const _CollectionItemCard(
      {required this.item,
      required this.isResume,
      required this.onTap,
      this.onPlan});
  final CollectionItem item;
  final bool isResume;
  final VoidCallback onTap;
  final Future<void> Function()? onPlan;

  @override
  Widget build(BuildContext context) => ContentCard(
        onTap: onTap,
        semanticLabel:
            '${item.isLocked ? 'Закритий' : 'Відкрити'} матеріал ${item.content.title}',
        child: Row(children: [
          CircleAvatar(child: Icon(_kindIcon(item.content.contentKind))),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      AppBadge(
                          label: _kindLabel(item.content.contentKind),
                          icon: _kindIcon(item.content.contentKind)),
                      if (item.isPreview)
                        const AppBadge(label: 'Безкоштовний перегляд'),
                      if (item.isLocked)
                        const AppBadge(
                            label: 'Закрито', icon: Icons.lock_outline),
                      if (isResume)
                        const AppBadge(
                            label: 'Продовжити',
                            icon: Icons.play_arrow_rounded),
                    ]),
                const SizedBox(height: AppSpacing.xs),
                Text(item.content.title,
                    style: Theme.of(context).textTheme.titleMedium),
                if (!item.isLocked)
                  Text(item.content.description,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
          if (onPlan != null)
            IconButton(
                icon: const Icon(Icons.calendar_month_outlined),
                tooltip: 'Запланувати',
                onPressed: onPlan),
          Icon(item.isLocked ? Icons.lock_outline : Icons.chevron_right),
        ]),
      );
}

String _kindLabel(ContentKind kind) => switch (kind) {
      ContentKind.recipe => 'Рецепт',
      ContentKind.technique => 'Техніка',
      ContentKind.process => 'Процес',
      ContentKind.video => 'Відео'
    };
IconData _kindIcon(ContentKind kind) => switch (kind) {
      ContentKind.recipe => Icons.restaurant_menu_rounded,
      ContentKind.technique => Icons.auto_awesome_outlined,
      ContentKind.process => Icons.format_list_numbered_rounded,
      ContentKind.video => Icons.play_circle_outline_rounded
    };

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();
  @override
  Widget build(BuildContext context) => const Column(children: [
        AppSkeleton(height: 300),
        Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: AppSkeleton(height: 92))
      ]);
}
