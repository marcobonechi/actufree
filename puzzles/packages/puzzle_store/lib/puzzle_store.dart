/// The persistence contract shared by the pure-Dart game engines and the
/// Flutter shell.
///
/// Depends on nothing, so an engine can implement [SavedGame] without any
/// route to a Flutter import.
library;

export 'src/best_scores.dart';
export 'src/game_store.dart';
export 'src/saved_game.dart';
