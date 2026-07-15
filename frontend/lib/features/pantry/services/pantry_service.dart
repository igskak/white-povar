import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../models/pantry_models.dart';

class PantryService {
  const PantryService(this._api);
  final ApiClient _api;
  static const _pendingKey = 'pantry.pending-mutations.v1';

  Future<List<PantryItem>> pantry() async {
    await _flushPending();
    return ((await _api.get<List<dynamic>>('/api/v1/pantry')).data ?? [])
        .map((e) => PantryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PantryItem> addPantry(PantryItem item) => _mutate(
      () async => PantryItem.fromJson((await _api.post<Map<String, dynamic>>(
              '/api/v1/pantry',
              data: item.toJson()))
          .data!),
      fallback: item,
      method: 'post',
      path: '/api/v1/pantry',
      data: item.toJson());

  Future<List<ShoppingItem>> shopping() async {
    await _flushPending();
    final data =
        (await _api.get<Map<String, dynamic>>('/api/v1/shopping-list')).data!;
    return (data['items'] as List<dynamic>? ?? [])
        .map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ShoppingItem> addShopping(ShoppingItem item) => _mutate(
      () async => ShoppingItem.fromJson((await _api.post<Map<String, dynamic>>(
              '/api/v1/shopping-list',
              data: item.toJson()))
          .data!),
      fallback: item,
      method: 'post',
      path: '/api/v1/shopping-list',
      data: item.toJson());
  Future<ShoppingItem> updateShopping(ShoppingItem item) => _mutate(
      () async => ShoppingItem.fromJson((await _api.put<Map<String, dynamic>>(
              '/api/v1/shopping-list/${item.id}',
              data: item.toJson()))
          .data!),
      fallback: item,
      method: 'put',
      path: '/api/v1/shopping-list/${item.id}',
      data: item.toJson());
  Future<void> addRecipe(String recipeId, int servings) => _api
      .post<Map<String, dynamic>>('/api/v1/shopping-list/from-recipe/$recipeId',
          data: {'servings': servings});

  Future<T> _mutate<T>(Future<T> Function() request,
      {required T fallback,
      required String method,
      required String path,
      required Map<String, dynamic> data}) async {
    try {
      return await request();
    } on ApiError catch (error) {
      if (!_offline(error)) rethrow;
      await _enqueue(method, path, data);
      return fallback;
    }
  }

  bool _offline(ApiError error) =>
      error.type == ApiErrorType.network || error.type == ApiErrorType.timeout;
  Future<void> _enqueue(
      String method, String path, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(_pendingKey) ?? [];
    entries.add(jsonEncode({'method': method, 'path': path, 'data': data}));
    await prefs.setStringList(_pendingKey, entries);
  }

  Future<void> _flushPending() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(_pendingKey) ?? [];
    if (entries.isEmpty) return;
    final remaining = <String>[];
    for (final raw in entries) {
      final entry = jsonDecode(raw) as Map<String, dynamic>;
      try {
        if (entry['method'] == 'put') {
          await _api.put<Map<String, dynamic>>(entry['path'] as String,
              data: entry['data']);
        } else {
          await _api.post<Map<String, dynamic>>(entry['path'] as String,
              data: entry['data']);
        }
      } on ApiError catch (error) {
        if (_offline(error)) remaining.add(raw);
      }
    }
    await prefs.setStringList(_pendingKey, remaining);
  }
}
