import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/search_provider.dart';
import '../../models/search_filters.dart';
import '../widgets/search_filters_panel.dart';
import '../widgets/search_results_list.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/search_suggestions_widget.dart';

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
  bool _showFilters = false;
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
      _showSuggestions = _searchController.text.isNotEmpty && _searchFocusNode.hasFocus;
    });
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final searchState = ref.read(searchProvider);
    final filters = searchState.filters.copyWith(query: query);
    
    ref.read(searchProvider.notifier).search(filters: filters);
    ref.read(searchHistoryProvider.notifier).addSearch(query);
    
    _searchFocusNode.unfocus();
    setState(() {
      _showSuggestions = false;
    });
  }

  void _onSuggestionSelected(String suggestion) {
    _searchController.text = suggestion;
    _performSearch();
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchProvider.notifier).clearSearch();
    setState(() {
      _showSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Recipes'),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list : Icons.filter_list_outlined),
            onPressed: _toggleFilters,
            tooltip: 'Filters',
          ),
          if (searchState.hasResults)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSearch,
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
            child: Row(
              children: [
                // Filters Panel
                if (_showFilters)
                  Container(
                    width: 300,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: const SearchFiltersPanel(),
                  ),
                
                // Main Content
                Expanded(
                  child: Stack(
                    children: [
                      // Search Results
                      const SearchResultsList(),
                      
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
          ),
        ],
      ),
    );
  }
}
