import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/advanced_search_service.dart';
import '../models/search_filters.dart';
import '../models/search_response.dart';
import '../models/filter_options.dart';
import '../../recipes/models/recipe.dart';

// Search Service Provider
final searchServiceProvider = Provider<AdvancedSearchService>((ref) {
  final service = AdvancedSearchService.instance;
  service.initialize();
  return service;
});

// Search State
class SearchState {
  final SearchResponse? searchResponse;
  final bool isLoading;
  final String? error;
  final SearchFilters filters;
  final int currentPage;

  const SearchState({
    this.searchResponse,
    this.isLoading = false,
    this.error,
    this.filters = const SearchFilters(),
    this.currentPage = 1,
  });

  SearchState copyWith({
    SearchResponse? searchResponse,
    bool? isLoading,
    String? error,
    SearchFilters? filters,
    int? currentPage,
  }) {
    return SearchState(
      searchResponse: searchResponse ?? this.searchResponse,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filters: filters ?? this.filters,
      currentPage: currentPage ?? this.currentPage,
    );
  }

  List<Recipe> get recipes => searchResponse?.recipes ?? [];
  int get totalCount => searchResponse?.totalCount ?? 0;
  bool get hasResults => recipes.isNotEmpty;
  bool get hasMore => searchResponse?.hasNext ?? false;
}

// Search Notifier
class SearchNotifier extends StateNotifier<SearchState> {
  final AdvancedSearchService _searchService;

  SearchNotifier(this._searchService) : super(const SearchState());

  Future<void> search({
    SearchFilters? filters,
    int page = 1,
    bool append = false,
  }) async {
    final searchFilters = filters ?? state.filters;
    
    if (!append) {
      state = state.copyWith(
        isLoading: true,
        error: null,
        filters: searchFilters,
        currentPage: page,
      );
    }

    try {
      final response = await _searchService.advancedSearch(
        filters: searchFilters,
        page: page,
        pageSize: 20,
      );

      if (append && state.searchResponse != null) {
        // Append new recipes to existing ones
        final existingRecipes = state.searchResponse!.recipes;
        final newRecipes = [...existingRecipes, ...response.recipes];
        
        final updatedResponse = SearchResponse(
          recipes: newRecipes,
          totalCount: response.totalCount,
          page: response.page,
          pageSize: response.pageSize,
          totalPages: response.totalPages,
          hasNext: response.hasNext,
          hasPrev: response.hasPrev,
          filtersApplied: response.filtersApplied,
        );

        state = state.copyWith(
          searchResponse: updatedResponse,
          isLoading: false,
          currentPage: page,
        );
      } else {
        state = state.copyWith(
          searchResponse: response,
          isLoading: false,
          currentPage: page,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.hasMore && !state.isLoading) {
      await search(
        page: state.currentPage + 1,
        append: true,
      );
    }
  }

  void updateFilters(SearchFilters filters) {
    state = state.copyWith(filters: filters);
  }

  void clearSearch() {
    state = const SearchState();
  }

  Future<void> quickSearch(String query) async {
    final filters = SearchFilters(query: query);
    await search(filters: filters);
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final searchService = ref.watch(searchServiceProvider);
  return SearchNotifier(searchService);
});

// Search Suggestions Provider
final searchSuggestionsProvider = FutureProvider.family<List<String>, String>((ref, query) async {
  if (query.length < 2) return [];
  
  final searchService = ref.watch(searchServiceProvider);
  return await searchService.getSearchSuggestions(query: query);
});

// Popular Searches Provider
final popularSearchesProvider = FutureProvider<List<String>>((ref) async {
  final searchService = ref.watch(searchServiceProvider);
  return await searchService.getPopularSearches();
});

// Filter Options Provider
final filterOptionsProvider = FutureProvider<FilterOptions>((ref) async {
  final searchService = ref.watch(searchServiceProvider);
  return await searchService.getFilterOptions();
});

// Simple Search Provider (for backward compatibility)
final simpleSearchProvider = FutureProvider.family<List<Recipe>, Map<String, dynamic>>((ref, params) async {
  final searchService = ref.watch(searchServiceProvider);
  
  return await searchService.simpleSearch(
    query: params['query'],
    cuisine: params['cuisine'],
    difficulty: params['difficulty'],
    maxTime: params['maxTime'],
    page: params['page'] ?? 1,
    pageSize: params['pageSize'] ?? 20,
  );
});

// Photo Search Provider
final photoSearchProvider = FutureProvider.family<List<Recipe>, Map<String, dynamic>>((ref, params) async {
  final searchService = ref.watch(searchServiceProvider);
  
  return await searchService.searchByPhoto(
    base64Image: params['image'],
    chefId: params['chefId'],
    maxResults: params['maxResults'] ?? 10,
  );
});

// Search History State (local storage)
class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super([]);

  void addSearch(String query) {
    if (query.trim().isEmpty) return;
    
    final trimmedQuery = query.trim();
    final updatedHistory = [trimmedQuery];
    
    // Add existing items that don't match the new query
    for (final item in state) {
      if (item != trimmedQuery && updatedHistory.length < 10) {
        updatedHistory.add(item);
      }
    }
    
    state = updatedHistory;
  }

  void removeSearch(String query) {
    state = state.where((item) => item != query).toList();
  }

  void clearHistory() {
    state = [];
  }
}

final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});
