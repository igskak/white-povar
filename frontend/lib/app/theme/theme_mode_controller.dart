import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ThemeModeStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesThemeModeStorage implements ThemeModeStorage {
  const SharedPreferencesThemeModeStorage();
  static const _key = 'theme_mode';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String value) async =>
      (await SharedPreferences.getInstance()).setString(_key, value);
}

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._storage) : super(ThemeMode.system) {
    _restore();
  }

  final ThemeModeStorage _storage;

  Future<void> _restore() async {
    final value = await _storage.read();
    state = ThemeMode.values.where((mode) => mode.name == value).firstOrNull ??
        ThemeMode.system;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _storage.write(mode.name);
  }
}

final appThemeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(const SharedPreferencesThemeModeStorage()),
);
