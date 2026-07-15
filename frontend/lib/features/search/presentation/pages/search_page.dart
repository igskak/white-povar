import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../app/router/route_models.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../recipes/models/recipe.dart';
import '../../../recipes/presentation/widgets/recipe_card.dart';
import '../../providers/search_provider.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.initialRoute});

  final SearchRouteLocation? initialRoute;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _showFilters = false;
  String? _activeTag;
  String? _selectedRecipeId;
  final List<String> _recentSearches = [];

  static const _suggestions = [
    'Швидка вечеря',
    'З овочами',
    'Сніданок',
    'Паста',
  ];

  static const _filters = [
    _DiscoveryFilter('До 30 хв', Icons.schedule_outlined),
    _DiscoveryFilter('Без м’яса', Icons.eco_outlined),
    _DiscoveryFilter('Для родини', Icons.people_outline),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final initialValue = widget.initialRoute?.query ?? widget.initialRoute?.tag;
    if (initialValue == null) return;

    _searchController.text = initialValue;
    _activeTag = widget.initialRoute?.tag;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _performSearch(initialValue);
    });
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final route = widget.initialRoute;
    if (route == oldWidget.initialRoute || route == null) return;
    final value = route.query ?? route.tag ?? '';
    if (value == _searchController.text && route.tag == _activeTag) return;
    _searchController.text = value;
    _activeTag = route.tag;
    if (value.isEmpty) {
      ref.read(simpleTextSearchProvider.notifier).clearSearch();
    } else {
      _performSearch(value);
    }
  }

  void _performSearch(String query) {
    ref.read(simpleTextSearchProvider.notifier).searchRecipes(query);
  }

  void _applySuggestion(String value) {
    setState(() {
      _activeTag = null;
      _searchController.text = value;
    });
    _updateLocation();
    _performSearch(value);
  }

  void _applyTag(String tag) {
    setState(() {
      _activeTag = tag;
      _searchController.text = tag;
    });
    _updateLocation();
    _performSearch(tag);
  }

  void _updateLocation() {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    router.go(
      SearchRouteLocation(
        query: _activeTag == null ? _searchController.text.trim() : null,
        tag: _activeTag,
      ).toUri().toString(),
    );
  }

  void _rememberSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    setState(() {
      _recentSearches.remove(query);
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 3) _recentSearches.removeLast();
    });
  }

  void _clearSearch() {
    setState(() {
      _activeTag = null;
      _selectedRecipeId = null;
      _searchController.clear();
    });
    _updateLocation();
    ref.read(simpleTextSearchProvider.notifier).clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(simpleTextSearchProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ResponsiveContainer(
              maxWidth: 1280,
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: _SearchHeader(
                  controller: _searchController,
                  isLoading: searchState.isLoading,
                  showFilters: _showFilters,
                  activeTag: _activeTag,
                  filters: _filters,
                  onToggleFilters: () =>
                      setState(() => _showFilters = !_showFilters),
                  onClear: _clearSearch,
                  onChanged: (value) {
                    setState(() => _activeTag = null);
                    _updateLocation();
                    if (value.trim().length >= 2) {
                      _performSearch(value);
                    } else if (value.trim().isEmpty) {
                      ref.read(simpleTextSearchProvider.notifier).clearSearch();
                    }
                  },
                  onSubmitted: (value) {
                    _rememberSearch(value);
                    _performSearch(value);
                  },
                  onFilterSelected: _applySuggestion,
                ),
              ),
            ),
            Expanded(child: _buildBody(searchState)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(SimpleSearchState searchState) {
    if (searchState.error != null) {
      return StateView.error(
        title: 'Пошук не спрацював',
        subtitle: searchState.error,
        onRetry: () => _performSearch(_searchController.text),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return _DiscoveryStart(
        recentSearches: _recentSearches,
        suggestions: _suggestions,
        onSelected: _applySuggestion,
        onTagSelected: _applyTag,
      );
    }

    if (searchState.isLoading && searchState.results.isEmpty) {
      return const _SearchSkeleton();
    }

    if (searchState.results.isEmpty) {
      return _NoResults(
        suggestions: _suggestions,
        onClear: _clearSearch,
        onSelected: _applySuggestion,
      );
    }

    return _SearchResults(
      recipes: searchState.results,
      selectedRecipeId: _selectedRecipeId,
      onSelected: (recipe) => setState(() => _selectedRecipeId = recipe.id),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader(
      {required this.controller,
      required this.isLoading,
      required this.showFilters,
      required this.activeTag,
      required this.filters,
      required this.onToggleFilters,
      required this.onClear,
      required this.onChanged,
      required this.onSubmitted,
      required this.onFilterSelected});
  final TextEditingController controller;
  final bool isLoading;
  final bool showFilters;
  final String? activeTag;
  final List<_DiscoveryFilter> filters;
  final VoidCallback onToggleFilters;
  final VoidCallback onClear;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onFilterSelected;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Пошук', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('Рецепти, інгредієнти та добірки Олександра.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColorsV2.textSecondary)),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
            controller: controller,
            hint: 'Наприклад: томати, паста, вечеря',
            prefixIcon: const Icon(Icons.search),
            textInputAction: TextInputAction.search,
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              if (isLoading)
                const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              if (controller.text.isNotEmpty)
                AppIconButton(
                    icon: Icons.clear, tooltip: 'Очистити', onPressed: onClear)
            ]),
            onChanged: onChanged,
            onSubmitted: onSubmitted),
        const SizedBox(height: AppSpacing.xs),
        Row(children: [
          AppButton(
              label: showFilters ? 'Сховати фільтри' : 'Фільтри',
              icon: Icons.tune_outlined,
              variant: AppButtonVariant.text,
              onPressed: onToggleFilters),
          if (activeTag != null)
            Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: AppChip(
                    label: 'Тег: $activeTag',
                    selected: true,
                    onSelected: (_) => onClear()))
        ]),
        AnimatedSize(
            duration: AppMotion.medium,
            child: showFilters
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: filters
                            .map((filter) => AppChip(
                                label: filter.label,
                                avatar: Icon(filter.icon, size: 16),
                                onSelected: (_) =>
                                    onFilterSelected(filter.label)))
                            .toList()))
                : const SizedBox.shrink()),
        const SizedBox(height: AppSpacing.sm),
      ]);
}

class _DiscoveryStart extends StatelessWidget {
  const _DiscoveryStart(
      {required this.recentSearches,
      required this.suggestions,
      required this.onSelected,
      required this.onTagSelected});
  final List<String> recentSearches;
  final List<String> suggestions;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onTagSelected;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
        Text('Що готуємо сьогодні?',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text('Почніть з інгредієнта або добірки.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColorsV2.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
        if (recentSearches.isNotEmpty) ...[
          Text('Нещодавні', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: recentSearches
                  .map((item) => AppChip(
                      label: item,
                      avatar: const Icon(Icons.history, size: 16),
                      onSelected: (_) => onSelected(item)))
                  .toList()),
          const SizedBox(height: AppSpacing.lg)
        ],
        Text('Спробуйте', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: suggestions
                .map((item) =>
                    AppChip(label: item, onSelected: (_) => onSelected(item)))
                .toList()),
        const SizedBox(height: AppSpacing.lg),
        ContentCard(
            onTap: () => onTagSelected('maisternia-oleksandra'),
            semanticLabel: 'Відкрити добірку Майстерня Олександра',
            child: Row(children: [
              const Icon(Icons.workspace_premium_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Майстерня Олександра',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Text('Відкрити рецепти з добірки')
                  ]))
            ]))
      ]);
}

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();
  @override
  Widget build(BuildContext context) => GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 380,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: .9),
      itemCount: 6,
      itemBuilder: (_, __) => const Card(
          child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: AppSkeleton(
                            height: double.infinity,
                            borderRadius: AppRadius.md)),
                    SizedBox(height: AppSpacing.md),
                    AppSkeleton(width: 180, height: 20),
                    SizedBox(height: AppSpacing.xs),
                    AppSkeleton(width: 240),
                    SizedBox(height: AppSpacing.xs),
                    AppSkeleton(width: 140)
                  ]))));
}

class _NoResults extends StatelessWidget {
  const _NoResults(
      {required this.suggestions,
      required this.onClear,
      required this.onSelected});
  final List<String> suggestions;
  final VoidCallback onClear;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => Center(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.search_off_rounded, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text('Нічого не знайшли',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text('Спробуйте інший інгредієнт або коротший запит.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColorsV2.textSecondary)),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Скинути пошук', onPressed: onClear),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: suggestions
                    .map((item) => AppChip(
                        label: item, onSelected: (_) => onSelected(item)))
                    .toList())
          ])));
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.recipes,
    required this.selectedRecipeId,
    required this.onSelected,
  });

  final List<Recipe> recipes;
  final String? selectedRecipeId;
  final ValueChanged<Recipe> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1024) {
            final selected = recipes
                    .where((recipe) => recipe.id == selectedRecipeId)
                    .firstOrNull ??
                recipes.first;
            return Row(
              children: [
                SizedBox(
                  width: 420,
                  child: _RecipeList(
                    recipes: recipes,
                    selectedRecipeId: selected.id,
                    onSelected: onSelected,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: _DiscoveryPreview(
                      recipe: selected,
                      onOpen: () => context.push('/recipes/${selected.id}'),
                    ),
                  ),
                ),
              ],
            );
          }
          final columns = constraints.maxWidth >= 600 ? 3 : 1;
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              // RecipeCard keeps all metadata visible at large text scales.
              childAspectRatio: columns == 1 ? .75 : .55,
            ),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return RecipeCard(
                recipe: recipe,
                onTap: () => context.push('/recipes/${recipe.id}'),
              );
            },
          );
        },
      );
}

class _RecipeList extends StatelessWidget {
  const _RecipeList(
      {required this.recipes,
      required this.selectedRecipeId,
      required this.onSelected});
  final List<Recipe> recipes;
  final String selectedRecipeId;
  final ValueChanged<Recipe> onSelected;
  @override
  Widget build(BuildContext context) => ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: recipes.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return ListTile(
            selected: recipe.id == selectedRecipeId,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
            leading: recipe.isPremium
                ? const Icon(Icons.lock_outline)
                : const Icon(Icons.restaurant_menu_outlined),
            title: Text(recipe.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${recipe.totalTimeMinutes} хв · ${recipe.cuisine}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => onSelected(recipe));
      });
}

class _DiscoveryPreview extends StatelessWidget {
  const _DiscoveryPreview({required this.recipe, required this.onOpen});
  final Recipe recipe;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Обраний рецепт',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Expanded(child: RecipeCard(recipe: recipe, onTap: onOpen)),
            const SizedBox(height: AppSpacing.md),
            AppButton(
                label: 'Відкрити рецепт',
                icon: Icons.arrow_forward,
                expand: true,
                onPressed: onOpen)
          ])));
}

class _DiscoveryFilter {
  const _DiscoveryFilter(this.label, this.icon);
  final String label;
  final IconData icon;
}
