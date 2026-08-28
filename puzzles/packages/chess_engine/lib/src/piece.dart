/// Which side a piece belongs to.
enum PieceColor {
  /// The side that moves first and starts on ranks one and two.
  white,

  /// The side that replies.
  black;

  /// The other side.
  PieceColor get opponent => this == white ? black : white;

  /// The side's name, for anything the player reads.
  String get label => this == white ? 'White' : 'Black';
}

/// What a piece is.
enum PieceKind {
  /// Forward only, captures diagonally, promotes at the far end.
  pawn('P', 1),

  /// The one that jumps.
  knight('N', 3),

  /// Diagonals, and so one colour of square for the whole game.
  bishop('B', 3),

  /// Ranks and files.
  rook('R', 5),

  /// Rook and bishop at once.
  queen('Q', 9),

  /// The one the game is about.
  king('K', 0);

  const PieceKind(this.letter, this.value);

  /// The letter algebraic notation uses, uppercase.
  ///
  /// The pawn's `P` is never printed in notation — `e4` names the square and
  /// leaves the piece implied — but it is what FEN writes, so it is here.
  final String letter;

  /// The conventional material value in pawns.
  ///
  /// Zero for the king, which is not material: it cannot be traded, so
  /// counting it would only ever add the same number to both sides.
  final int value;

  /// The kinds a pawn may promote to, in the order a chooser should offer
  /// them.
  static const List<PieceKind> promotions = <PieceKind>[
    queen,
    rook,
    bishop,
    knight,
  ];
}

/// A piece: what it is and whose it is.
///
/// A value type. There is nothing to distinguish one white knight from the
/// other, and a board that held identities rather than values would invite
/// code that cared which one it was looking at.
final class ChessPiece {
  /// A [kind] belonging to [color].
  const ChessPiece(this.color, this.kind);

  /// The piece [symbol] stands for in FEN — uppercase White, lowercase Black
  /// — or `null` when it stands for nothing.
  static ChessPiece? fromSymbol(String symbol) {
    if (symbol.length != 1) return null;
    final upper = symbol.toUpperCase();
    for (final kind in PieceKind.values) {
      if (kind.letter != upper) continue;
      return ChessPiece(
        symbol == upper ? PieceColor.white : PieceColor.black,
        kind,
      );
    }
    return null;
  }

  /// Whose it is.
  final PieceColor color;

  /// What it is.
  final PieceKind kind;

  /// The FEN symbol: uppercase for White, lowercase for Black.
  String get symbol => color == PieceColor.white
      ? kind.letter
      : kind.letter.toLowerCase();

  /// Whether this piece moves any distance along a line, so its path can be
  /// blocked.
  bool get slides =>
      kind == PieceKind.bishop ||
      kind == PieceKind.rook ||
      kind == PieceKind.queen;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChessPiece && other.color == color && other.kind == kind;

  @override
  int get hashCode => Object.hash(color, kind);

  @override
  String toString() => symbol;
}
