import 'package:flutter/material.dart';
import 'package:puzzle_store/puzzle_store.dart';

/// The player's preferences, and where they are kept.
///
/// Only the theme so far. Sound, haptics and the rest join it here rather than
/// growing a second settings mechanism.
class SettingsController extends ChangeNotifier {
  SettingsController._(this._store, this._themeMode);

  /// Reads settings out of [store], falling back to defaults.
  static Future<SettingsController> load(KeyValueStore store) async {
    return SettingsController._(store, _parseThemeMode(await store.read(_themeKey)));
  }

  static const String _themeKey = 'settings/themeMode';

  final KeyValueStore _store;
  ThemeMode _themeMode;

  /// Whether to follow the device, or force light or dark.
  ThemeMode get themeMode => _themeMode;

  /// Changes the theme and remembers the choice.
  ///
  /// Notifies before the write completes: the player should see the theme
  /// change immediately, not after a round trip to disk.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _store.write(_themeKey, mode.name);
  }

  /// An unrecognised or missing value means "follow the device", which is also
  /// what a fresh install gets.
  static ThemeMode _parseThemeMode(String? stored) {
    for (final mode in ThemeMode.values) {
      if (mode.name == stored) return mode;
    }
    return ThemeMode.system;
  }
}
