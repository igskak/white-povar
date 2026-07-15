import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../app/router/route_models.dart';
import '../../../../core/widgets/state_views.dart';
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
  String? _quickFilter;

  static const _quickFilters = [
    'Сніданок',
    'Паста',
    'Курка',
    'Салат',
    'Десерт',
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
    _quickFilter = widget.initialRoute?.tag;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _performSearch(initialValue);
    });
  }

  void _performSearch(String query) {
    ref.read(simpleTextSearchProvider.notifier).searchRecipes(query);
  }

  void _applyQuickFilter(String value) {
    setState(() {
      _quickFilter = value;
      _searchController.text = value;
    });
    _performSearch(value);
  }

  void _clearSearch() {
    setState(() {
      _quickFilter = null;
      _searchController.clear();
    });
    ref.read(simpleTextSearchProvider.notifier).clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(simpleTextSearchProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Пошук',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Знайдіть рецепт за інгредієнтом, назвою або кухнею.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColorsV2.textSecondary,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Наприклад: томати, паста, вечеря',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (searchState.isLoading)
                              const Padding(
                                padding: EdgeInsets.all(AppSpacing.sm),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                tooltip: 'Очистити',
                                onPressed: _clearSearch,
                              ),
                          ],
                        ),
                      ),
                      onChanged: (value) {
                        setState(() => _quickFilter = null);
                        if (value.trim().length >= 2) {
                          _performSearch(value);
                        } else if (value.trim().isEmpty) {
                          ref
                              .read(simpleTextSearchProvider.notifier)
                              .clearSearch();
                        }
                      },
                      onSubmitted: _performSearch,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _showFilters = !_showFilters);
                      },
                      icon: Icon(
                        _showFilters ? Icons.tune_rounded : Icons.tune_outlined,
                      ),
                      label: Text(
                        _showFilters ? 'Сховати фільтри' : 'Швидкі фільтри',
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: AppMotion.medium,
                      child: _showFilters
                          ? Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.xs,
                              ),
                              child: Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: _quickFilters.map((filter) {
                                  return ChoiceChip(
                                    label: Text(filter),
                                    selected: _quickFilter == filter,
                                    onSelected: (_) =>
                                        _applyQuickFilter(filter),
                                  );
                                }).toList(),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
            ..._resultSlivers(searchState),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }

  List<Widget> _resultSlivers(SimpleSearchState searchState) {
    if (searchState.error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StateView.error(
            title: 'Пошук не спрацював',
            subtitle: searchState.error,
            onRetry: () => _performSearch(_searchController.text),
          ),
        ),
      ];
    }

    if (_searchController.text.trim().isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StateView.empty(
            title: 'Що готуємо сьогодні?',
            subtitle: 'Введіть інгредієнт або відкрийте швидкі фільтри.',
            icon: Icons.search_rounded,
          ),
        ),
      ];
    }

    if (searchState.isLoading && searchState.results.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StateView.loading(
            title: 'Шукаємо рецепти',
            subtitle: 'Перевіряємо каталог White Povar.',
          ),
        ),
      ];
    }

    if (searchState.results.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StateView.empty(
            title: 'Нічого не знайшли',
            subtitle: 'Спробуйте інший інгредієнт або коротший запит.',
            icon: Icons.search_off_rounded,
            onRetry: _clearSearch,
            actionLabel: 'Скинути',
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.all(AppSpacing.md),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.crossAxisExtent;
            final columns = width >= 900
                ? 3
                : width >= 600
                    ? 2
                    : 1;
            return SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                childAspectRatio: columns == 1 ? 0.92 : 0.72,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final recipe = searchState.results[index];
                  return RecipeCard(
                    recipe: recipe,
                    onTap: () => context.push('/recipes/${recipe.id}'),
                  );
                },
                childCount: searchState.results.length,
              ),
            );
          },
        ),
      ),
    ];
  }
}
