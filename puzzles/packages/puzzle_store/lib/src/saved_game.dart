/// A game state that can be written to storage and read back.
///
/// This lives in a pure-Dart package on purpose. The obvious home would be the
/// shared Flutter layer, but an engine implementing an interface from there
/// would have to depend on it, and so on Flutter — which is exactly what the
/// engines are built to avoid. Putting the contract in a package that depends
/// on nothing lets both sides meet in the middle.
abstract interface class SavedGame {
  /// A stable identifier for the game this state belongs to, such as
  /// `sudoku`.
  ///
  /// Used to route a stored record back to the right decoder, so it must not
  /// change once anything has been written.
  String get gameId;

  /// The state, as JSON-encodable maps, lists, strings, numbers and booleans.
  Map<String, Object?> toJson();
}

/// Rebuilds a [SavedGame] of type [T] from what [SavedGame.toJson] wrote.
typedef SavedGameDecoder<T extends SavedGame> = T Function(
  Map<String, Object?> json,
);
