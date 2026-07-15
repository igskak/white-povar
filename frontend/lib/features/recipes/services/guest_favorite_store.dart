import 'package:shared_preferences/shared_preferences.dart';

/// Durable, device-local save intents made before an account exists.
///
/// These IDs are deliberately kept separate from authenticated cache data: they
/// are migrated only after a successful authenticated favorite write.
class GuestFavoriteStore {
  static const _key = 'core04.guest-favorite-ids.v1';

  Future<Set<String>> read() async {
    final values = (await SharedPreferences.getInstance()).getStringList(_key);
    return values == null ? <String>{} : values.toSet();
  }

  Future<void> add(String recipeId) async {
    final preferences = await SharedPreferences.getInstance();
    final ids = (preferences.getStringList(_key) ?? <String>[]).toSet()
      ..add(recipeId);
    await preferences.setStringList(_key, ids.toList()..sort());
  }

  Future<void> remove(String recipeId) async {
    final preferences = await SharedPreferences.getInstance();
    final ids = (preferences.getStringList(_key) ?? <String>[]).toSet()
      ..remove(recipeId);
    if (ids.isEmpty) {
      await preferences.remove(_key);
    } else {
      await preferences.setStringList(_key, ids.toList()..sort());
    }
  }
}
