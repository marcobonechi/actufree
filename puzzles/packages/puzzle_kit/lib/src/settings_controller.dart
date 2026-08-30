import 'package:flutter/material.dart';
import 'package:puzzle_store/puzzle_store.dart';

/// The player's preferences, and where they are kept.
///
/// The theme and the music so far. Haptics and the rest join them here rather
/// than growing a second settings mechanism.
class SettingsController extends ChangeNotifier {
  SettingsController._(
    this._store,
    this._themeMode,
    this._musicMuted,
    this._musicVolume,
  );

  /// Reads settings out of [store], falling back to defaults.
  static Future<SettingsController> load(KeyValueStore store) async {
    return SettingsController._(
      store,
      _parseThemeMode(await store.read(_themeKey)),
      await store.read(_musicMutedKey) == 'true',
      _parseVolume(await store.read(_musicVolumeKey)),
    );
  }

  static const String _themeKey = 'settings/themeMode';
  static const String _musicMutedKey = 'settings/musicMuted';
  static const String _musicVolumeKey = 'settings/musicVolume';

  /// Loud enough to be there, quiet enough to think over. A puzzle is played
  /// in the music's company, not in front of it.
  static const double defaultMusicVolume = 0.35;

  final KeyValueStore _store;
  ThemeMode _themeMode;
  bool _musicMuted;
  double _musicVolume;

  /// Whether to follow the device, or force light or dark.
  ThemeMode get themeMode => _themeMode;

  /// Whether the music is silenced.
  ///
  /// Kept apart from a volume of zero: someone who mutes and later unmutes
  /// should get their volume back, not have to find it again.
  bool get musicMuted => _musicMuted;

  /// How loud the music is, from 0 (silent) to 1 (full).
  double get musicVolume => _musicVolume;

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

  /// Silences the music, or lets it back in, and remembers which.
  Future<void> setMusicMuted(bool muted) async {
    if (muted == _musicMuted) return;
    _musicMuted = muted;
    notifyListeners();
    await _store.write(_musicMutedKey, muted.toString());
  }

  /// Sets how loud the music is and remembers it.
  ///
  /// Values outside 0 to 1 are pulled back into range rather than refused: a
  /// slider that has been dragged past its end still means "as far as it
  /// goes".
  Future<void> setMusicVolume(double volume) async {
    final double wanted = volume.clamp(0, 1).toDouble();
    if (wanted == _musicVolume) return;
    _musicVolume = wanted;
    notifyListeners();
    await _store.write(_musicVolumeKey, wanted.toString());
  }

  /// An unrecognised or missing value means the default volume — the same
  /// thing a fresh install gets.
  static double _parseVolume(String? stored) {
    final double? parsed = stored == null ? null : double.tryParse(stored);
    if (parsed == null || parsed.isNaN) return defaultMusicVolume;
    return parsed.clamp(0, 1).toDouble();
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
