import 'dart:typed_data';

import 'piece.dart';
import 'position.dart';
import 'square.dart';

/// What a piece is worth, in centipawns — hundredths of a pawn.
///
/// The conventional values, except that the bishop is put a little above the
/// knight. That difference is most of what makes a computer willing to give up
/// a knight for a bishop, which is the trade a beginner is most surprised to
/// see and the one that is usually right.
const Map<PieceKind, int> kPieceValue = <PieceKind, int>{
  PieceKind.pawn: 100,
  PieceKind.knight: 320,
  PieceKind.bishop: 335,
  PieceKind.rook: 500,
  PieceKind.queen: 950,
  PieceKind.king: 0,
};

/// The score returned for a position where the side to move is mated.
///
/// Far outside the range any material count can reach, so a mate is never
/// weighed against a queen. [mateIn] is how the search shortens it by the
/// number of moves it takes, which is what makes a computer that can mate in
/// two prefer that to mating in five.
const int kMateScore = 30000;

/// A bishop pair is worth more than two bishops.
///
/// The two of them cover both square colours between them, which is the whole
/// of the advantage and the reason it disappears the moment one is traded.
const int kBishopPairBonus = 30;

/// What a doubled pawn costs.
const int kDoubledPawnPenalty = 14;

/// What a pawn with no friendly pawn on either neighbouring file costs.
const int kIsolatedPawnPenalty = 16;

/// How good [position] looks for the side to move, in centipawns.
///
/// Positive means the side to move is better off. Everything here is static:
/// it counts what is on the board and where it stands, and knows nothing about
/// what could happen next. Seeing two moves ahead is the search's job, and
/// asking an evaluation to be clever about tactics is how you get one that is
/// slow and still wrong.
///
/// The parts are material, a table per piece saying where that piece likes to
/// stand, the bishop pair, and the two pawn-structure faults that are cheap to
/// spot. That is a deliberately short list. A computer that plays sensibly and
/// answers in under a second beats one that plays beautifully and takes ten.
int evaluate(Position position) {
  var material = 0;
  var placement = 0;
  var whiteBishops = 0;
  var blackBishops = 0;
  var whiteKing = 0;
  var blackKing = 0;
  var nonPawnMaterial = 0;
  // Pawns per file, White in the first eight slots and Black in the second.
  // One flat list rather than two: this runs at every leaf of the search, and
  // the allocations are the part that shows up.
  final pawns = Uint8List(boardSize * 2);

  for (final square in Square.all) {
    final piece = position.pieceAt(square);
    if (piece == null) continue;
    final white = piece.color == PieceColor.white;
    final sign = white ? 1 : -1;
    switch (piece.kind) {
      case PieceKind.king:
        // The king's table depends on how far into the endgame this is,
        // which is not known until the sweep is over.
        if (white) {
          whiteKing = _mirrored(square, white: true);
        } else {
          blackKing = _mirrored(square, white: false);
        }
        continue;
      case PieceKind.pawn:
        pawns[(white ? 0 : boardSize) + square.col]++;
      case PieceKind.bishop:
        if (white) {
          whiteBishops++;
        } else {
          blackBishops++;
        }
        nonPawnMaterial += kPieceValue[piece.kind]!;
      case PieceKind.knight || PieceKind.rook || PieceKind.queen:
        nonPawnMaterial += kPieceValue[piece.kind]!;
    }
    material += sign * kPieceValue[piece.kind]!;
    placement += sign * _tables[piece.kind.index][_mirrored(square, white: white)];
  }

  final phase = (1 - nonPawnMaterial / _openingMaterial).clamp(0, 1).toDouble();
  placement += _kingPlacement(whiteKing, phase) - _kingPlacement(blackKing, phase);

  var structure = 0;
  if (whiteBishops >= 2) structure += kBishopPairBonus;
  if (blackBishops >= 2) structure -= kBishopPairBonus;
  for (var file = 0; file < boardSize; file++) {
    for (final white in const <bool>[true, false]) {
      final base = white ? 0 : boardSize;
      final count = pawns[base + file];
      if (count == 0) continue;
      final sign = white ? 1 : -1;
      if (count > 1) structure -= sign * kDoubledPawnPenalty * (count - 1);
      final left = file > 0 ? pawns[base + file - 1] : 0;
      final right = file < boardSize - 1 ? pawns[base + file + 1] : 0;
      if (left == 0 && right == 0) {
        structure -= sign * kIsolatedPawnPenalty * count;
      }
    }
  }

  // Everything above is counted from White's side. The search wants it from
  // the side to move's.
  final total = material + placement + structure;
  return position.sideToMove == PieceColor.white ? total : -total;
}

/// Where [square] reads in a table written from White's side.
int _mirrored(Square square, {required bool white}) =>
    (white ? square.row : boardSize - 1 - square.row) * boardSize + square.col;

/// What a king on [index] is worth, sliding between its two tables.
int _kingPlacement(int index, double phase) {
  final middle = _kingMiddlegame[index];
  final end = _kingEndgame[index];
  return (middle + (end - middle) * phase).round();
}

/// Both sides' knights, bishops, rooks and queen at the start of the game.
const int _openingMaterial = 2 * (2 * 320 + 2 * 335 + 2 * 500 + 950);

/// A mate score adjusted for how far away it is.
///
/// Deeper mates score lower, so the search prefers the quick one. Also lets a
/// score be recognised as a mate: anything within [boardSize] * 16 of the top
/// is one.
int mateIn(int ply) => kMateScore - ply;

/// Whether [score] is a mate rather than an ordinary evaluation.
bool isMateScore(int score) => score.abs() > kMateScore - 256;

/// How far [row], [col] is from the middle of the board, in squares.
///
/// The tables are generated from this rather than typed out. Sixty-four
/// numbers per piece is sixty-four chances to fat-finger one, and a table with
/// a typo in it plays a slightly strange game that nobody can account for —
/// whereas a rule that is wrong is wrong visibly, and can be argued with.
double _centreDistance(int row, int col) {
  final dr = (row - 3.5).abs();
  final dc = (col - 3.5).abs();
  return (dr + dc) / 2;
}

/// The rank a white piece on [row] stands on, counting from one.
int _rank(int row) => boardSize - row;

List<int> _generate(int Function(int row, int col) value) => List<int>.generate(
      squareCount,
      (index) => value(index ~/ boardSize, index % boardSize),
      growable: false,
    );

/// Pawns: worth more the further they have walked, and worth more in the
/// middle than on the wing — but not on the second rank, where the d and e
/// pawns are only in the way of the pieces behind them.
final List<int> _pawnTable = _generate((int row, int col) {
  final rank = _rank(row);
  if (rank == 1 || rank == 8) return 0;
  final advance = (rank - 2) * (rank - 2) * 2;
  final central = (col == 3 || col == 4) ? (rank >= 4 ? 14 : -12) : 0;
  final wing = (col == 0 || col == 7) ? -6 : 0;
  return advance + central + wing;
});

/// Knights: everything they can do depends on how many squares they reach, and
/// a knight in the corner reaches two.
final List<int> _knightTable = _generate((int row, int col) {
  final centre = (2.5 - _centreDistance(row, col)) * 12;
  final home = _rank(row) == 1 ? -14 : 0;
  return centre.round() + home;
});

/// Bishops: mild centralisation, a nudge for the long diagonals, and a
/// reminder that a bishop on its starting square is doing nothing.
final List<int> _bishopTable = _generate((int row, int col) {
  final centre = (2.5 - _centreDistance(row, col)) * 6;
  final diagonal = (row == col || row + col == 7) ? 8 : 0;
  final home = _rank(row) == 1 ? -12 : 0;
  return centre.round() + diagonal + home;
});

/// Rooks: the seventh rank, where they eat pawns and cut the king off, and the
/// middle files, which are the ones that tend to open.
final List<int> _rookTable = _generate((int row, int col) {
  final seventh = _rank(row) == 7 ? 22 : 0;
  final central = (col >= 2 && col <= 5) ? 6 : 0;
  return seventh + central;
});

/// Queens: barely any preference. A queen is worth what a queen is worth, and
/// a table with strong opinions about where she stands mostly succeeds in
/// bringing her out too early.
final List<int> _queenTable = _generate((int row, int col) {
  final centre = (2.5 - _centreDistance(row, col)) * 3;
  final home = _rank(row) == 1 ? -6 : 0;
  return centre.round() + home;
});

/// The king in the middlegame: behind its own pawns, towards a corner, and
/// nowhere near the middle.
final List<int> _kingMiddlegame = _generate((int row, int col) {
  final rank = _rank(row);
  if (rank > 2) return -12 * (rank - 2);
  final castled = rank == 1 && (col <= 2 || col >= 6) ? 26 : 0;
  final centreFile = rank == 1 && (col == 3 || col == 4) ? -14 : 0;
  return castled + centreFile;
});

/// The king in the endgame: in the middle, where it is a piece again.
final List<int> _kingEndgame = _generate(
  (int row, int col) => ((2.5 - _centreDistance(row, col)) * 16).round(),
);

/// The tables, indexed by [PieceKind.index] so that a leaf evaluation is a
/// list lookup rather than a hash.
///
/// The king's slot is empty: it has two tables and is handled apart.
final List<List<int>> _tables = <List<int>>[
  _pawnTable,
  _knightTable,
  _bishopTable,
  _rookTable,
  _queenTable,
  const <int>[],
];
