import 'dart:convert';

import 'saved_game.dart';

/// Somewhere durable to put bytes, keyed by a string.
///
/// Deliberately this small: the shell supplies an implementation backed by the
/// platform, and everything above it stays testable in plain Dart with a map.
abstract interface class KeyValueStore {
  /// The value stored under [key], or `null` when there is none.
  Future<String?> read(String key);

  /// Stores [value] under [key].
  Future<void> write(String key, String value);

  /// Removes whatever is under [key].
  Future<void> remove(String key);
}

/// A [KeyValueStore] held in memory, for tests.
class MemoryStore implements KeyValueStore {
  final Map<String, String> _entries = <String, String>{};

  /// The keys currently held.
  Iterable<String> get keys => _entries.keys;

  @override
  Future<String?> read(String key) async => _entries[key];

  @override
  Future<void> write(String key, String value) async => _entries[key] = value;

  @override
  Future<void> remove(String key) async => _entries.remove(key);
}

/// Reads and writes [SavedGame]s, one per slot.
///
/// A slot is whatever the caller wants to key games by — Sudoku uses the
/// difficulty, so a game in progress on Hard does not evict one on Easy.
class GameStore {
  /// Stores games in [store].
  const GameStore(this._store);

  /// The envelope version, so a future format change can be recognised rather
  /// than crashing on a record it does not understand.
  static const int version = 1;

  final KeyValueStore _store;

  /// The key a record lands under. Exposed so tests can be explicit.
  static String keyFor(String gameId, String slot) => 'game/$gameId/$slot';

  /// Writes [game] to [slot].
  Future<void> save(SavedGame game, {required String slot}) {
    final envelope = <String, Object?>{
      'version': version,
      'gameId': game.gameId,
      'slot': slot,
      'state': game.toJson(),
    };
    return _store.write(keyFor(game.gameId, slot), jsonEncode(envelope));
  }

  /// Reads the game in [slot], or `null` when there is none.
  ///
  /// Returns `null` rather than throwing when the record is unreadable — a
  /// corrupt or outdated save should cost the player one game, not the ability
  /// to open the app. The bad record is cleared on the way out.
  Future<T?> load<T extends SavedGame>(
    String gameId,
    SavedGameDecoder<T> decode, {
    required String slot,
  }) async {
    final key = keyFor(gameId, slot);
    final raw = await _store.read(key);
    if (raw == null) return null;
    try {
      final envelope = jsonDecode(raw);
      if (envelope is! Map<String, Object?>) throw const FormatException();
      if (envelope['version'] != version) throw const FormatException();
      if (envelope['gameId'] != gameId) throw const FormatException();
      final state = envelope['state'];
      if (state is! Map<String, Object?>) throw const FormatException();
      return decode(state);
    } on Object {
      await _store.remove(key);
      return null;
    }
  }

  /// Whether [slot] holds a game.
  Future<bool> has(String gameId, {required String slot}) async =>
      await _store.read(keyFor(gameId, slot)) != null;

  /// Clears [slot].
  Future<void> clear(String gameId, {required String slot}) =>
      _store.remove(keyFor(gameId, slot));
}
