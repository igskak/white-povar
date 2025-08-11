import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../models/search_filters.dart';
import '../models/search_response.dart';
import '../models/filter_options.dart';
import '../../recipes/models/recipe.dart';

class AdvancedSearchService {
  static AdvancedSearchService? _instance;
  static AdvancedSearchService get instance => _instance ??= AdvancedSearchService._();
  
  AdvancedSearchService._();
  
  late final Dio _dio;
  
  void initialize() {
    _dio = Dio(BaseOptions(
      baseUrl: '${AppConfig.apiBaseUrl}/search',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));
    
    // Add auth interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Add auth token if available
        // final token = AuthService.instance.currentToken;
        // if (token != null) {
        //   options.headers['Authorization'] = 'Bearer $token';
        // }
        handler.next(options);
      },
    ));
  }
  
  Future<SearchResponse> advancedSearch({
    required SearchFilters filters,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _dio.post('/advanced', 
        data: filters.toJson(),
        queryParameters: {
          'page': page,
          'page_size': pageSize,
        },
      );
      
      return SearchResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<List<Recipe>> simpleSearch({
    String? query,
    String? cuisine,
    int? difficulty,
    int? maxTime,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      
      if (query != null) queryParams['q'] = query;
      if (cuisine != null) queryParams['cuisine'] = cuisine;
      if (difficulty != null) queryParams['difficulty'] = difficulty;
      if (maxTime != null) queryParams['max_time'] = maxTime;
      
      final response = await _dio.get('/recipes', queryParameters: queryParams);
      
      final List<dynamic> data = response.data;
      return data.map((json) => Recipe.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<List<String>> getSearchSuggestions({
    required String query,
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get('/suggestions', queryParameters: {
        'q': query,
        'limit': limit,
      });
      
      final Map<String, dynamic> data = response.data;
      final List<String> suggestions = [];
      
      // Combine all suggestion types
      if (data['recipes'] != null) {
        suggestions.addAll(List<String>.from(data['recipes']));
      }
      if (data['cuisines'] != null) {
        suggestions.addAll(List<String>.from(data['cuisines']));
      }
      if (data['ingredients'] != null) {
        suggestions.addAll(List<String>.from(data['ingredients']));
      }
      if (data['tags'] != null) {
        suggestions.addAll(List<String>.from(data['tags']));
      }
      
      return suggestions.take(limit).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<List<String>> getPopularSearches({int limit = 10}) async {
    try {
      final response = await _dio.get('/popular', queryParameters: {
        'limit': limit,
      });
      
      return List<String>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<FilterOptions> getFilterOptions() async {
    try {
      final response = await _dio.get('/filters');
      
      return FilterOptions.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<List<Recipe>> searchByPhoto({
    required String base64Image,
    String? chefId,
    int maxResults = 10,
  }) async {
    try {
      final response = await _dio.post('/photo', data: {
        'image': base64Image,
        'chef_id': chefId,
        'max_results': maxResults,
      });
      
      final List<dynamic> suggestedRecipes = response.data['suggested_recipes'] ?? [];
      return suggestedRecipes.map((json) => Recipe.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<List<Recipe>> searchByText({
    required String query,
    String? chefId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get('/text', queryParameters: {
        'q': query,
        'chef_id': chefId,
        'limit': limit,
        'offset': offset,
      });
      
      final List<dynamic> recipes = response.data['recipes'] ?? [];
      return recipes.map((json) => Recipe.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.badResponse:
        if (e.response?.statusCode == 401) {
          return 'Authentication required. Please log in.';
        } else if (e.response?.statusCode == 400) {
          return e.response?.data['detail'] ?? 'Invalid search parameters.';
        }
        return e.response?.data['detail'] ?? 'Server error occurred.';
      case DioExceptionType.cancel:
        return 'Search was cancelled.';
      default:
        return 'Network error. Please check your connection.';
    }
  }
}
