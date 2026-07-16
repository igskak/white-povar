import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../models/menu_plan.dart';

class MenuPlanService {
  const MenuPlanService(this._api);
  final ApiClient _api;
  static const _pendingKey = 'menu-plan.pending-mutations.v1';
  Future<MenuPlanWeek> week(DateTime monday) async {
    await _flush();
    final data = (await _api.get<Map<String, dynamic>>('/api/v1/menu-plan',
            queryParameters: {'week_start': _date(monday)}))
        .data!;
    return MenuPlanWeek.fromJson(data);
  }

  Future<void> add(
          {required DateTime day,
          required String recipeId,
          String? collectionId,
          required int servings}) =>
      _mutate('post', '/api/v1/menu-plan/slots', {
        'planned_for': _date(day),
        'recipe_id': recipeId,
        'collection_id': collectionId,
        'servings': servings,
        'position': 999
      });
  Future<void> update(MenuPlanSlot slot) =>
      _mutate('put', '/api/v1/menu-plan/slots/${slot.id}', slot.input());
  Future<void> remove(String id) =>
      _mutate('delete', '/api/v1/menu-plan/slots/$id', null);
  Future<void> reorder(DateTime monday, List<MenuPlanSlot> slots) => _mutate(
      'put',
      '/api/v1/menu-plan/reorder?week_start=${_date(monday)}',
      {'slot_ids': slots.map((e) => e.id).toList()});
  Future<void> addMissing(DateTime monday) async {
    await _api.post('/api/v1/menu-plan/shopping-list',
        data: {'week_start': _date(monday)});
  }

  Future<String> share(DateTime monday) async =>
      ((await _api.post<Map<String, dynamic>>('/api/v1/menu-plan/share',
              data: {'week_start': _date(monday)}))
          .data!['text'] as String);
  Future<void> _mutate(String method, String path, dynamic data) async {
    try {
      await _request(method, path, data);
    } on ApiError catch (error) {
      if (error.type != ApiErrorType.network &&
          error.type != ApiErrorType.timeout) rethrow;
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(_pendingKey) ?? [];
      pending.add(jsonEncode({'method': method, 'path': path, 'data': data}));
      await prefs.setStringList(_pendingKey, pending);
    }
  }

  Future<void> _flush() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingKey) ?? [];
    final keep = <String>[];
    for (final raw in pending) {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      try {
        await _request(
            value['method'] as String, value['path'] as String, value['data']);
      } on ApiError catch (error) {
        if (error.type == ApiErrorType.network ||
            error.type == ApiErrorType.timeout) keep.add(raw);
      }
    }
    await prefs.setStringList(_pendingKey, keep);
  }

  Future<void> _request(String method, String path, dynamic data) async {
    switch (method) {
      case 'post':
        await _api.post(path, data: data);
      case 'put':
        await _api.put(path, data: data);
      case 'delete':
        await _api.delete(path);
      default:
        throw ArgumentError(method);
    }
  }

  String _date(DateTime value) => value.toIso8601String().substring(0, 10);
}
