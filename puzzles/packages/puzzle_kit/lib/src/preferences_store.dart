import 'package:puzzle_store/puzzle_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [KeyValueStore] backed by the platform's own small-value storage.
///
/// This is the only place in the codebase that knows how bytes reach the
/// device. Everything above it works against [KeyValueStore], so the tests use
/// a plain map and the storage plugin can be swapped here alone.
class PreferencesStore implements KeyValueStore {
  /// Wraps an open [SharedPreferences].
  const PreferencesStore(this._preferences);

  /// Opens the platform store.
  static Future<PreferencesStore> open() async =>
      PreferencesStore(await SharedPreferences.getInstance());

  final SharedPreferences _preferences;

  @override
  Future<String?> read(String key) async => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}
