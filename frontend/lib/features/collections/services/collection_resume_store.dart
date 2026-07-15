import 'package:shared_preferences/shared_preferences.dart';

/// Remembers only the last opened item ID, not a course-progress state.
class CollectionResumeStore {
  static const _prefix = 'col03.last-item.';

  Future<String?> read(String collectionId) async =>
      (await SharedPreferences.getInstance())
          .getString('$_prefix$collectionId');

  Future<void> save(String collectionId, String itemId) async =>
      (await SharedPreferences.getInstance())
          .setString('$_prefix$collectionId', itemId);

  Future<void> clearPrivateData() async {
    final preferences = await SharedPreferences.getInstance();
    for (final key
        in preferences.getKeys().where((key) => key.startsWith(_prefix))) {
      await preferences.remove(key);
    }
  }
}
