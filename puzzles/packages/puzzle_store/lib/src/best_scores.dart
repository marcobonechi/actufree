import 'game_store.dart';

/// The best score each game has managed on this device.
///
/// Lives here rather than in the Flutter layer because it is persistence and
/// nothing else, and because a game that keeps a score should be able to ask
/// about it without reaching for a widget.
///
/// Deliberately not a leaderboard. Nothing leaves the device, so this is one
/// number per game, and it exists to give a run something to beat.
class BestScores {
  /// Keeps scores in [store].
  const BestScores(this._store);

  final KeyValueStore _store;

  /// The key a game's best lands under. Exposed so tests can be explicit.
  static String keyFor(String gameId) => 'best/$gameId';

  /// The best score [gameId] has seen, or zero when it has none.
  ///
  /// An unreadable value counts as none: a score is not worth failing to open
  /// the app over.
  Future<int> best(String gameId) async {
    final raw = await _store.read(keyFor(gameId));
    if (raw == null) return 0;
    return int.tryParse(raw) ?? 0;
  }

  /// Records [score] for [gameId], and says whether it beat what was there.
  ///
  /// The answer is the point: a screen wants to say "best yet" at the moment
  /// it happens, and asking again afterwards would always say yes.
  Future<bool> record(String gameId, int score) async {
    if (score <= await best(gameId)) return false;
    await _store.write(keyFor(gameId), '$score');
    return true;
  }

  /// Forgets [gameId]'s best.
  Future<void> clear(String gameId) => _store.remove(keyFor(gameId));
}
