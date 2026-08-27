import 'board.dart';
import 'coord.dart';
import 'game.dart';

/// Why a placement could not be made.
enum PlacementRejection {
  /// There is no piece in that slot of the hand.
  noPieceThere('That piece has already been played'),

  /// The shape would leave the board or overlap something already on it.
  doesNotFit('That piece does not fit there');

  const PlacementRejection(this.message);

  /// A short human-readable explanation.
  final String message;
}

/// The result of dropping a piece on the board.
sealed class PlacementResult {
  const PlacementResult();
}

/// The piece was placed. [game] is the game that follows.
final class PlacementAccepted extends PlacementResult {
  /// Records a placement.
  const PlacementAccepted({
    required this.game,
    required this.filled,
    required this.clear,
    required this.points,
    required this.dealt,
  });

  /// The game after the placement, the clear and any new hand.
  final BlockGame game;

  /// The cells the piece landed on.
  ///
  /// These are where the piece went, not where it still is: a cell here may
  /// also appear in [LineClear.cells], having been filled and cleared by the
  /// same move. Drawing wants both — the piece should be seen landing before
  /// the line it completed goes out.
  final Set<Coord> filled;

  /// What the placement cleared, empty when it completed no line.
  final LineClear clear;

  /// What the placement scored.
  final int points;

  /// Whether emptying the hand brought a new one.
  final bool dealt;

  /// Whether the game ended here.
  bool get isOver => game.isOver;
}

/// The piece was not placed, and nothing changed.
final class PlacementRejected extends PlacementResult {
  /// Records a refusal.
  const PlacementRejected(this.reason);

  /// Why it was refused.
  final PlacementRejection reason;
}
