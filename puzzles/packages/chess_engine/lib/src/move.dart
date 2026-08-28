import 'piece.dart';
import 'square.dart';

/// What kind of move this is, where the difference changes what happens to
/// the board beyond moving one piece.
enum MoveKind {
  /// A piece moves, and takes whatever is on the destination square.
  normal,

  /// A pawn's opening two-square move, which leaves it capturable in passing.
  doublePawnPush,

  /// A pawn takes a pawn that has just gone past it, so the captured piece is
  /// not on the destination square.
  enPassant,

  /// The king goes two squares towards the h-file and the rook hops over it.
  castleKingside,

  /// The same towards the a-file.
  castleQueenside;

  /// Whether this is one of the two castles.
  bool get isCastle => this == castleKingside || this == castleQueenside;
}

/// One move: where a piece goes, and everything about it that the board could
/// not work out from the destination square alone.
///
/// Moves are made by the position that generated them. [kind], [moved] and
/// [captured] are recorded at generation time rather than rediscovered later,
/// which is what lets a move be described — or drawn as a capture — after the
/// board it was played on has moved on.
///
/// Equality is on [from], [to] and [promotion] only. Those three identify a
/// legal move uniquely in any position, so a move parsed from a save compares
/// equal to the generated one it names, without the parser having to know what
/// it captured.
final class Move {
  /// Records a move.
  const Move({
    required this.from,
    required this.to,
    required this.moved,
    this.kind = MoveKind.normal,
    this.captured,
    this.promotion,
  });

  /// Where the piece started.
  final Square from;

  /// Where it ends up.
  final Square to;

  /// The piece that moves.
  final PieceKind moved;

  /// Which of the special cases this is.
  final MoveKind kind;

  /// What it takes, or `null` when it takes nothing.
  final PieceKind? captured;

  /// What a promoting pawn becomes, or `null` when this is not a promotion.
  final PieceKind? promotion;

  /// Whether anything comes off the board.
  bool get isCapture => captured != null;

  /// The square the captured piece actually stands on.
  ///
  /// [to] for every capture but one: taking en passant removes a pawn beside
  /// the destination square rather than on it, which is the whole oddity of
  /// the move and the one place a board that assumed otherwise would leave a
  /// ghost pawn behind.
  Square? get captureSquare {
    if (captured == null) return null;
    if (kind != MoveKind.enPassant) return to;
    return Square(from.row, to.col);
  }

  /// The move in the notation engines talk to each other in, such as `e2e4`
  /// or `e7e8q`.
  ///
  /// Used here as the save format. It is short, it is unambiguous given the
  /// position it is played in, and it does not change meaning as the rest of
  /// the game is edited the way a move number would.
  String get uci =>
      '${from.name}${to.name}${promotion?.letter.toLowerCase() ?? ''}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Move &&
          other.from == from &&
          other.to == to &&
          other.promotion == promotion;

  @override
  int get hashCode => Object.hash(from, to, promotion);

  @override
  String toString() => uci;
}
