import 'piece.dart';

/// Why a game ended.
enum GameEnding {
  /// The king is attacked and there is nothing to be done about it.
  checkmate('Checkmate'),

  /// Nothing legal to play, and the king is not even in check.
  stalemate('Stalemate'),

  /// Fifty moves each without a capture or a pawn move.
  fiftyMoveRule('Fifty-move rule'),

  /// The same position, with the same moves available, for the third time.
  threefoldRepetition('Threefold repetition'),

  /// Neither side has enough left on the board to mate with.
  insufficientMaterial('Insufficient material');

  const GameEnding(this.label);

  /// What to call it.
  final String label;

  /// Whether this ending is a draw whoever was winning.
  bool get isDraw => this != checkmate;
}

/// How a game finished.
final class Outcome {
  /// Records an ending.
  const Outcome(this.ending, {this.winner});

  /// Why it is over.
  final GameEnding ending;

  /// Who won, or `null` for a draw.
  final PieceColor? winner;

  /// Whether nobody won.
  bool get isDraw => winner == null;

  /// A line saying what happened, for the player.
  String get label => winner == null
      ? 'Draw — ${ending.label.toLowerCase()}'
      : '${ending.label} — ${winner!.label} wins';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Outcome && other.ending == ending && other.winner == winner;

  @override
  int get hashCode => Object.hash(ending, winner);

  @override
  String toString() => label;
}
