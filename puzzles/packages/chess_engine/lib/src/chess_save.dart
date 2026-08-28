import 'package:puzzle_store/puzzle_store.dart';

import 'game.dart';
import 'opponent.dart';

/// A game of chess in progress: the moves, and who is playing them.
///
/// [ChessGame] deliberately does not implement [SavedGame] itself. The game is
/// the record of what was played and is answerable to the rules; who was
/// sitting on the other side is not a rule, and a game that carried a
/// difficulty level around would be a game the engine had opinions about.
///
/// The written form is the game's own fields with the opponent alongside them,
/// so a save from before the computer existed — which has no `opponent` field
/// — still reads, as the game between two people that it was.
final class ChessSave implements SavedGame {
  /// Creates a save.
  const ChessSave({
    required this.game,
    this.opponent = const Opponent.twoPlayers(),
  });

  /// Restores a save previously written by [toJson].
  factory ChessSave.fromJson(Map<String, Object?> json) {
    final opponent = json['opponent'];
    return ChessSave(
      game: ChessGame.fromJson(json),
      opponent: opponent == null
          ? const Opponent.twoPlayers()
          : opponent is Map<String, Object?>
              ? Opponent.fromJson(opponent)
              : throw const FormatException('malformed opponent'),
    );
  }

  /// The game.
  final ChessGame game;

  /// Who is playing it.
  final Opponent opponent;

  @override
  String get gameId => 'chess';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        ...game.toJson(),
        if (opponent.toJson() case final Map<String, Object?> written)
          'opponent': written,
      };
}
