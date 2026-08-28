import 'dart:typed_data';

import 'move.dart';
import 'piece.dart';
import 'square.dart';

/// The starting position, as FEN.
const String startingFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// How many half-moves without a pawn move or a capture make a draw.
const int fiftyMoveLimit = 100;

const int _whiteKingside = 1;
const int _whiteQueenside = 2;
const int _blackKingside = 4;
const int _blackQueenside = 8;

const List<List<int>> _knightSteps = <List<int>>[
  <int>[-2, -1], <int>[-2, 1], <int>[-1, -2], <int>[-1, 2],
  <int>[1, -2], <int>[1, 2], <int>[2, -1], <int>[2, 1],
];

const List<List<int>> _kingSteps = <List<int>>[
  <int>[-1, -1], <int>[-1, 0], <int>[-1, 1], <int>[0, -1],
  <int>[0, 1], <int>[1, -1], <int>[1, 0], <int>[1, 1],
];

const List<List<int>> _rookRays = <List<int>>[
  <int>[-1, 0], <int>[1, 0], <int>[0, -1], <int>[0, 1],
];

const List<List<int>> _bishopRays = <List<int>>[
  <int>[-1, -1], <int>[-1, 1], <int>[1, -1], <int>[1, 1],
];

/// A position: the pieces, whose turn it is, and the state that only the
/// history of the game can tell you — castling rights, the en passant square
/// and the two clocks.
///
/// Immutable. [makeMove] hands back a new position, which is what lets a game
/// keep every position it has been in for the repetition rule, and lets the
/// screen hold on to the one before the last move without it changing
/// underneath.
///
/// Everything here is the rules and nothing here is strategy. There is no
/// evaluation and no search: this is a two-player game, and the engine's job
/// is to say what is legal, not what is good.
final class Position {
  Position._(
    this._board,
    this._castling,
    this._whiteKing,
    this._blackKing, {
    required this.sideToMove,
    required this.enPassant,
    required this.halfmoveClock,
    required this.fullmoveNumber,
  });

  /// The position both players start from.
  factory Position.initial() => Position.fromFen(startingFen);

  /// The position [fen] describes.
  ///
  /// Forsyth-Edwards notation is the standard way to write a position down,
  /// which makes it the obvious thing for a test to be written in and the
  /// obvious thing for a save to hold.
  factory Position.fromFen(String fen) {
    final fields = fen.trim().split(RegExp(r'\s+'));
    if (fields.length < 4) {
      throw FormatException('a FEN needs at least four fields', fen);
    }
    final board = Uint8List(squareCount);
    final ranks = fields[0].split('/');
    if (ranks.length != boardSize) {
      throw FormatException('a FEN needs $boardSize ranks', fen);
    }
    for (var row = 0; row < boardSize; row++) {
      var col = 0;
      for (final glyph in ranks[row].split('')) {
        final skip = int.tryParse(glyph);
        if (skip != null) {
          col += skip;
          continue;
        }
        final piece = ChessPiece.fromSymbol(glyph);
        if (piece == null || col >= boardSize) {
          throw FormatException('bad rank "${ranks[row]}"', fen);
        }
        board[row * boardSize + col] = _encode(piece);
        col++;
      }
      if (col != boardSize) {
        throw FormatException('rank "${ranks[row]}" is not $boardSize wide', fen);
      }
    }

    final side = switch (fields[1]) {
      'w' => PieceColor.white,
      'b' => PieceColor.black,
      _ => throw FormatException('side to move must be w or b', fen),
    };

    var castling = 0;
    if (fields[2] != '-') {
      for (final right in fields[2].split('')) {
        castling |= switch (right) {
          'K' => _whiteKingside,
          'Q' => _whiteQueenside,
          'k' => _blackKingside,
          'q' => _blackQueenside,
          _ => throw FormatException('bad castling field "${fields[2]}"', fen),
        };
      }
    }

    final enPassant = fields[3] == '-' ? null : Square.tryParse(fields[3]);
    if (fields[3] != '-' && enPassant == null) {
      throw FormatException('bad en passant square "${fields[3]}"', fen);
    }

    // A position missing a king is not a position: every rule below asks
    // where the king is, and a board without one would fail somewhere far
    // from the FEN that caused it. Found once here and carried from then on,
    // because a search asks the question at every node.
    final kings = <PieceColor, Square>{};
    for (final color in PieceColor.values) {
      final king = _findKingIn(board, color);
      if (king == null) {
        throw FormatException('no ${color.label.toLowerCase()} king', fen);
      }
      kings[color] = king;
    }

    return Position._(
      board,
      castling,
      kings[PieceColor.white]!,
      kings[PieceColor.black]!,
      sideToMove: side,
      enPassant: enPassant,
      halfmoveClock: fields.length > 4 ? int.tryParse(fields[4]) ?? 0 : 0,
      fullmoveNumber: fields.length > 5 ? int.tryParse(fields[5]) ?? 1 : 1,
    );
  }

  final Uint8List _board;
  final int _castling;
  final Square _whiteKing;
  final Square _blackKing;

  /// Whose turn it is.
  final PieceColor sideToMove;

  /// The square a pawn could be captured on in passing, or `null`.
  ///
  /// This is the square the capturing pawn moves *to*, which is the empty one
  /// the double-pushed pawn stepped over — not the square the pawn itself
  /// ended on.
  final Square? enPassant;

  /// Half-moves since the last pawn move or capture, for the fifty-move rule.
  final int halfmoveClock;

  /// The move number, counting from one and rising after Black's move.
  final int fullmoveNumber;

  List<Move>? _legalMoves;
  List<Move>? _pseudoLegalMoves;

  /// The piece on [square], or `null` when it is empty.
  ChessPiece? pieceAt(Square square) => _decode(_board[square.index]);

  /// Where [color]'s king stands.
  Square kingSquare(PieceColor color) =>
      color == PieceColor.white ? _whiteKing : _blackKing;

  /// Whether [color]'s king is under attack.
  bool isInCheck(PieceColor color) =>
      isAttacked(kingSquare(color), by: color.opponent);

  /// Whether the side to move is in check.
  bool get inCheck => isInCheck(sideToMove);

  /// Whether [by] attacks [square].
  ///
  /// Asked of the square a king stands on to find check, and of squares a
  /// king passes over to find out whether it may castle. Note that it asks
  /// about attacks, not about legal moves: a pinned piece still guards the
  /// squares it attacks, which is why this cannot be written in terms of
  /// [legalMoves] without going in a circle.
  bool isAttacked(Square square, {required PieceColor by}) {
    // Pawns, from the attacker's point of view: a white pawn attacks upwards,
    // so the white pawns that could be hitting this square stand below it.
    final pawnRow = by == PieceColor.white ? 1 : -1;
    for (final side in const <int>[-1, 1]) {
      final from = square.offset(pawnRow, side);
      if (from != null && pieceAt(from) == ChessPiece(by, PieceKind.pawn)) {
        return true;
      }
    }
    for (final step in _knightSteps) {
      final from = square.offset(step[0], step[1]);
      if (from != null && pieceAt(from) == ChessPiece(by, PieceKind.knight)) {
        return true;
      }
    }
    for (final step in _kingSteps) {
      final from = square.offset(step[0], step[1]);
      if (from != null && pieceAt(from) == ChessPiece(by, PieceKind.king)) {
        return true;
      }
    }
    if (_raysHit(square, _rookRays, by, PieceKind.rook)) return true;
    if (_raysHit(square, _bishopRays, by, PieceKind.bishop)) return true;
    return false;
  }

  /// Every legal move for the side to move.
  ///
  /// Worked out once and kept: the board asks for these on every rebuild, and
  /// a position never changes.
  List<Move> get legalMoves => _legalMoves ??= List<Move>.unmodifiable(
        pseudoLegalMoves.where((Move move) => tryMove(move) != null),
      );

  /// Every move the pieces could make if the king's safety were not a
  /// consideration.
  ///
  /// Includes moves that leave, or walk into, check — which are not moves at
  /// all. It is here for the search, which cannot afford [legalMoves]: proving
  /// a move legal means playing it, and alpha-beta abandons most of the moves
  /// it is offered without ever playing them. Checking on the way past, with
  /// [tryMove], costs one board instead of two.
  ///
  /// Anything drawing a board or accepting a player's tap wants [legalMoves].
  List<Move> get pseudoLegalMoves =>
      _pseudoLegalMoves ??= _computePseudoLegalMoves();

  /// The position after [move], or `null` when it would leave the mover's own
  /// king in check — which is to say, when it was never a move.
  Position? tryMove(Move move) {
    final after = makeMove(move);
    return after.isInCheck(sideToMove) ? null : after;
  }

  /// The legal moves that start on [square].
  List<Move> movesFrom(Square square) =>
      legalMoves.where((Move move) => move.from == square).toList(
            growable: false,
          );

  /// The legal move from [from] to [to], or `null` when there is none.
  ///
  /// [promotion] picks between the four moves a promoting pawn has; without
  /// it, a promoting move comes back as the queen. Every caller that matters
  /// — the board, and a save being replayed — knows a pair of squares and
  /// wants the move the rules make of them.
  Move? findMove(Square from, Square to, {PieceKind? promotion}) {
    for (final move in legalMoves) {
      if (move.from != from || move.to != to) continue;
      if (move.promotion == null) return move;
      if (move.promotion == (promotion ?? PieceKind.queen)) return move;
    }
    return null;
  }

  /// Whether moving from [from] to [to] would need a piece chosen for a
  /// promoting pawn.
  ///
  /// The screen has to ask before it can play the move, and asking after the
  /// fact is not an option — so this is separate from [findMove].
  bool isPromotion(Square from, Square to) => legalMoves.any(
        (Move move) =>
            move.from == from && move.to == to && move.promotion != null,
      );

  /// The position after [move] is played.
  ///
  /// The move is assumed to have come from [legalMoves]; this applies it
  /// rather than re-checking it.
  Position makeMove(Move move) {
    final board = Uint8List.fromList(_board);
    final mover = pieceAt(move.from)!;

    board[move.from.index] = 0;
    final capture = move.captureSquare;
    if (capture != null) board[capture.index] = 0;
    board[move.to.index] = _encode(
      ChessPiece(mover.color, move.promotion ?? mover.kind),
    );

    if (move.kind.isCastle) {
      final kingside = move.kind == MoveKind.castleKingside;
      final rookFrom = Square(move.from.row, kingside ? 7 : 0);
      final rookTo = Square(move.from.row, kingside ? 5 : 3);
      board[rookTo.index] = board[rookFrom.index];
      board[rookFrom.index] = 0;
    }

    // Rights are lost by the king or rook leaving home, and by a rook being
    // taken on its home square — that last one is the case that is easy to
    // forget, and it shows up as a castle into a rook that is no longer there.
    var castling = _castling;
    if (mover.kind == PieceKind.king) {
      castling &= mover.color == PieceColor.white ? ~3 : ~12;
    }
    for (final square in <Square>[move.from, move.to]) {
      castling &= switch (square.name) {
        'a1' => ~_whiteQueenside,
        'h1' => ~_whiteKingside,
        'a8' => ~_blackQueenside,
        'h8' => ~_blackKingside,
        _ => ~0,
      };
    }

    final resets = move.isCapture || mover.kind == PieceKind.pawn;
    final movedKing = mover.kind == PieceKind.king;
    return Position._(
      board,
      castling,
      movedKing && mover.color == PieceColor.white ? move.to : _whiteKing,
      movedKing && mover.color == PieceColor.black ? move.to : _blackKing,
      sideToMove: sideToMove.opponent,
      enPassant: move.kind == MoveKind.doublePawnPush
          ? Square((move.from.row + move.to.row) ~/ 2, move.from.col)
          : null,
      halfmoveClock: resets ? 0 : halfmoveClock + 1,
      fullmoveNumber:
          sideToMove == PieceColor.black ? fullmoveNumber + 1 : fullmoveNumber,
    );
  }

  /// Whether [color] may still castle on the king's side.
  bool canCastleKingside(PieceColor color) =>
      _castling &
          (color == PieceColor.white ? _whiteKingside : _blackKingside) !=
      0;

  /// Whether [color] may still castle on the queen's side.
  bool canCastleQueenside(PieceColor color) =>
      _castling &
          (color == PieceColor.white ? _whiteQueenside : _blackQueenside) !=
      0;

  /// Whether the side to move is mated: in check, with nothing legal.
  bool get isCheckmate => legalMoves.isEmpty && inCheck;

  /// Whether the side to move is stalemated: not in check, and still with
  /// nothing legal.
  bool get isStalemate => legalMoves.isEmpty && !inCheck;

  /// Whether neither side has the material to mate, however badly the other
  /// plays.
  ///
  /// The strict reading: king against king, king and one minor piece against
  /// king, and the two bishops on squares of one colour. Two knights are not
  /// here — mate with them cannot be forced, but it can be walked into, and a
  /// game that is still winnable is not a draw.
  bool get hasInsufficientMaterial {
    final minors = <PieceColor, List<Square>>{
      PieceColor.white: <Square>[],
      PieceColor.black: <Square>[],
    };
    for (final square in Square.all) {
      final piece = pieceAt(square);
      if (piece == null || piece.kind == PieceKind.king) continue;
      switch (piece.kind) {
        case PieceKind.pawn || PieceKind.rook || PieceKind.queen:
          return false;
        case PieceKind.knight || PieceKind.bishop:
          minors[piece.color]!.add(square);
        case PieceKind.king:
          break;
      }
    }
    final white = minors[PieceColor.white]!;
    final black = minors[PieceColor.black]!;
    if (white.length + black.length <= 1) return true;
    if (white.length == 1 && black.length == 1) {
      return pieceAt(white.single)!.kind == PieceKind.bishop &&
          pieceAt(black.single)!.kind == PieceKind.bishop &&
          white.single.isLight == black.single.isLight;
    }
    return false;
  }

  /// What the position looks like to the repetition rule.
  ///
  /// The first four FEN fields: the pieces, the turn, the castling rights and
  /// the en passant square. The clocks are left out on purpose — two
  /// positions that differ only in how long ago the last pawn moved are the
  /// same position as far as a threefold claim is concerned.
  String get repetitionKey =>
      '${_placement()} ${sideToMove == PieceColor.white ? 'w' : 'b'} '
      '${_castlingField()} ${enPassant?.name ?? '-'}';

  /// The position as FEN.
  String toFen() => '$repetitionKey $halfmoveClock $fullmoveNumber';

  @override
  String toString() => toFen();

  List<Move> _computePseudoLegalMoves() {
    final moves = <Move>[];
    for (final from in Square.all) {
      final piece = pieceAt(from);
      if (piece == null || piece.color != sideToMove) continue;
      switch (piece.kind) {
        case PieceKind.pawn:
          _addPawnMoves(moves, from);
        case PieceKind.knight:
          _addStepMoves(moves, from, PieceKind.knight, _knightSteps);
        case PieceKind.king:
          _addStepMoves(moves, from, PieceKind.king, _kingSteps);
          _addCastles(moves, from);
        case PieceKind.bishop:
          _addRayMoves(moves, from, PieceKind.bishop, _bishopRays);
        case PieceKind.rook:
          _addRayMoves(moves, from, PieceKind.rook, _rookRays);
        case PieceKind.queen:
          _addRayMoves(moves, from, PieceKind.queen, <List<int>>[
            ..._rookRays,
            ..._bishopRays,
          ]);
      }
    }
    return List<Move>.unmodifiable(moves);
  }

  void _addPawnMoves(List<Move> moves, Square from) {
    final forward = sideToMove == PieceColor.white ? -1 : 1;
    final startRow = sideToMove == PieceColor.white ? 6 : 1;

    final ahead = from.offset(forward, 0);
    if (ahead != null && pieceAt(ahead) == null) {
      _addPawnMove(moves, from, ahead, null, MoveKind.normal);
      final twoAhead = from.offset(forward * 2, 0);
      if (from.row == startRow && twoAhead != null && pieceAt(twoAhead) == null) {
        moves.add(
          Move(
            from: from,
            to: twoAhead,
            moved: PieceKind.pawn,
            kind: MoveKind.doublePawnPush,
          ),
        );
      }
    }

    for (final side in const <int>[-1, 1]) {
      final target = from.offset(forward, side);
      if (target == null) continue;
      final occupant = pieceAt(target);
      if (occupant != null && occupant.color != sideToMove) {
        _addPawnMove(moves, from, target, occupant.kind, MoveKind.normal);
      } else if (occupant == null && target == enPassant) {
        _addPawnMove(moves, from, target, PieceKind.pawn, MoveKind.enPassant);
      }
    }
  }

  /// Adds a pawn move, fanning it out into the four promotions when it lands
  /// on the far rank.
  void _addPawnMove(
    List<Move> moves,
    Square from,
    Square to,
    PieceKind? captured,
    MoveKind kind,
  ) {
    final lastRow = sideToMove == PieceColor.white ? 0 : boardSize - 1;
    if (to.row != lastRow) {
      moves.add(
        Move(
          from: from,
          to: to,
          moved: PieceKind.pawn,
          kind: kind,
          captured: captured,
        ),
      );
      return;
    }
    for (final promotion in PieceKind.promotions) {
      moves.add(
        Move(
          from: from,
          to: to,
          moved: PieceKind.pawn,
          kind: kind,
          captured: captured,
          promotion: promotion,
        ),
      );
    }
  }

  void _addStepMoves(
    List<Move> moves,
    Square from,
    PieceKind kind,
    List<List<int>> steps,
  ) {
    for (final step in steps) {
      final to = from.offset(step[0], step[1]);
      if (to == null) continue;
      final occupant = pieceAt(to);
      if (occupant?.color == sideToMove) continue;
      moves.add(
        Move(from: from, to: to, moved: kind, captured: occupant?.kind),
      );
    }
  }

  void _addRayMoves(
    List<Move> moves,
    Square from,
    PieceKind kind,
    List<List<int>> rays,
  ) {
    for (final ray in rays) {
      var to = from.offset(ray[0], ray[1]);
      while (to != null) {
        final occupant = pieceAt(to);
        if (occupant?.color == sideToMove) break;
        moves.add(
          Move(from: from, to: to, moved: kind, captured: occupant?.kind),
        );
        if (occupant != null) break;
        to = to.offset(ray[0], ray[1]);
      }
    }
  }

  /// Adds whichever castles are available.
  ///
  /// Three things have to hold beyond the right itself: the squares between
  /// king and rook are empty, the king is not in check, and it does not pass
  /// through an attacked square. The square it lands on is checked by the
  /// ordinary legality filter every other move goes through.
  void _addCastles(List<Move> moves, Square king) {
    if (inCheck) return;
    final row = sideToMove == PieceColor.white ? 7 : 0;
    if (king.row != row || king.col != 4) return;
    final rook = ChessPiece(sideToMove, PieceKind.rook);

    if (canCastleKingside(sideToMove) &&
        pieceAt(Square(row, 7)) == rook &&
        pieceAt(Square(row, 5)) == null &&
        pieceAt(Square(row, 6)) == null &&
        !isAttacked(Square(row, 5), by: sideToMove.opponent)) {
      moves.add(
        Move(
          from: king,
          to: Square(row, 6),
          moved: PieceKind.king,
          kind: MoveKind.castleKingside,
        ),
      );
    }

    if (canCastleQueenside(sideToMove) &&
        pieceAt(Square(row, 0)) == rook &&
        pieceAt(Square(row, 1)) == null &&
        pieceAt(Square(row, 2)) == null &&
        pieceAt(Square(row, 3)) == null &&
        !isAttacked(Square(row, 3), by: sideToMove.opponent)) {
      moves.add(
        Move(
          from: king,
          to: Square(row, 2),
          moved: PieceKind.king,
          kind: MoveKind.castleQueenside,
        ),
      );
    }
  }

  /// Whether a slider of [kind] or a queen belonging to [by] hits [square]
  /// along any of [rays].
  bool _raysHit(
    Square square,
    List<List<int>> rays,
    PieceColor by,
    PieceKind kind,
  ) {
    for (final ray in rays) {
      var scan = square.offset(ray[0], ray[1]);
      while (scan != null) {
        final piece = pieceAt(scan);
        if (piece != null) {
          if (piece.color == by &&
              (piece.kind == kind || piece.kind == PieceKind.queen)) {
            return true;
          }
          break;
        }
        scan = scan.offset(ray[0], ray[1]);
      }
    }
    return false;
  }

  static Square? _findKingIn(Uint8List board, PieceColor color) {
    final wanted = _encode(ChessPiece(color, PieceKind.king));
    for (var index = 0; index < squareCount; index++) {
      if (board[index] == wanted) return Square.fromIndex(index);
    }
    return null;
  }

  String _placement() {
    final ranks = <String>[];
    for (var row = 0; row < boardSize; row++) {
      final buffer = StringBuffer();
      var empty = 0;
      for (var col = 0; col < boardSize; col++) {
        final piece = _decode(_board[row * boardSize + col]);
        if (piece == null) {
          empty++;
          continue;
        }
        if (empty > 0) buffer.write(empty);
        empty = 0;
        buffer.write(piece.symbol);
      }
      if (empty > 0) buffer.write(empty);
      ranks.add(buffer.toString());
    }
    return ranks.join('/');
  }

  String _castlingField() {
    final buffer = StringBuffer();
    if (_castling & _whiteKingside != 0) buffer.write('K');
    if (_castling & _whiteQueenside != 0) buffer.write('Q');
    if (_castling & _blackKingside != 0) buffer.write('k');
    if (_castling & _blackQueenside != 0) buffer.write('q');
    return buffer.isEmpty ? '-' : buffer.toString();
  }

  static int _encode(ChessPiece piece) =>
      piece.kind.index + 1 + (piece.color == PieceColor.black ? 8 : 0);

  /// The twelve pieces there are, at the index [_encode] gives them.
  ///
  /// A lookup rather than a constructor call: a search asks what is on a
  /// square millions of times, and there is no sense in allocating a fresh
  /// white knight for each of them.
  static const List<ChessPiece?> _pieces = <ChessPiece?>[
    null,
    ChessPiece(PieceColor.white, PieceKind.pawn),
    ChessPiece(PieceColor.white, PieceKind.knight),
    ChessPiece(PieceColor.white, PieceKind.bishop),
    ChessPiece(PieceColor.white, PieceKind.rook),
    ChessPiece(PieceColor.white, PieceKind.queen),
    ChessPiece(PieceColor.white, PieceKind.king),
    null,
    null,
    ChessPiece(PieceColor.black, PieceKind.pawn),
    ChessPiece(PieceColor.black, PieceKind.knight),
    ChessPiece(PieceColor.black, PieceKind.bishop),
    ChessPiece(PieceColor.black, PieceKind.rook),
    ChessPiece(PieceColor.black, PieceKind.queen),
    ChessPiece(PieceColor.black, PieceKind.king),
  ];

  static ChessPiece? _decode(int code) => _pieces[code];
}
