import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/search_provider.dart';
import '../../models/search_filters.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/search_suggestions_widget.dart';
import '../../../recipes/presentation/widgets/recipe_card.dart';

class AdvancedSearchPage extends ConsumerStatefulWidget {
  final String? initialQuery;

  const AdvancedSearchPage({
    super.key,
    this.initialQuery,
  });

  @override
  ConsumerState<AdvancedSearchPage> createState() => _AdvancedSearchPageState();
}

class _AdvancedSearchPageState extends ConsumerState<AdvancedSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch();
      });
    }

    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    setState(() {
      _showSuggestions = query.isNotEmpty && _searchFocusNode.hasFocus;
    });
  }

  void _onFocusChanged() {
    setState(() {
      _showSuggestions =
          _searchController.text.isNotEmpty && _searchFocusNode.hasFocus;
    });
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final searchState = ref.read(searchProvider);
    final filters = searchState.filters.copyWith(query: query);

    ref.read(searchProvider.notifier).search(filters: filters);

    _searchFocusNode.unfocus();
    setState(() {
      _showSuggestions = false;
    });
  }

  void _onSuggestionSelected(String suggestion) {
    _searchController.text = suggestion;
    _performSearch();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchProvider.notifier).clearSearch();
    setState(() {
      _showSuggestions = false;
    });
  }

  bool _onScrollNotification(
    ScrollNotification notification,
    SearchState searchState,
  ) {
    if (!searchState.hasMore || searchState.isLoading) {
      return false;
    }

    final metrics = notification.metrics;
    final reachedLoadMoreThreshold =
        metrics.pixels >= metrics.maxScrollExtent - 300;
    if (reachedLoadMoreThreshold) {
      ref.read(searchProvider.notifier).loadMore();
    }

    return false;
  }

  Widget _buildSearchContent(SearchState searchState) {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final recipes = searchState.recipes;

    if (searchState.isLoading && recipes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchState.error != null && recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 56, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Search failed',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                searchState.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _performSearch,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!hasQuery) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Search for recipes',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use the search bar above to find recipes',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (recipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No recipes found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different keyword or remove some filters',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 800
                ? 3
                : 2;

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) =>
              _onScrollNotification(notification, searchState),
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: recipes.length + (searchState.isLoading ? 1 : 0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.78,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              if (index >= recipes.length) {
                return const Center(child: CircularProgressIndicator());
              }

              final recipe = recipes[index];
              return RecipeCard(
                recipe: recipe,
                onTap: () => context.push('/recipes/${recipe.id}'),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Search'),
        actions: [
          IconButton(
            onPressed: _clearSearch,
            icon: const Icon(Icons.clear),
            tooltip: 'Clear search',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SearchBarWidget(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onSubmitted: (_) => _performSearch(),
              onClear: _clearSearch,
            ),
          ),

          // Active Filters Indicator
          if (searchState.filters.activeFiltersCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${searchState.filters.activeFiltersCount} filter(s) applied',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      ref.read(searchProvider.notifier).updateFilters(
                            const SearchFilters(),
                          );
                    },
                    child: const Text('Clear all'),
                  ),
                ],
              ),
            ),

          // Content Area
          Expanded(
            child: Stack(
              children: [
                _buildSearchContent(searchState),

                // Search Suggestions Overlay
                if (_showSuggestions)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SearchSuggestionsWidget(
                      query: _searchController.text,
                      onSuggestionSelected: _onSuggestionSelected,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
