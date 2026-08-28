import 'move.dart';
import 'piece.dart';
import 'position.dart';
import 'square.dart';

/// Writes [move] the way a score sheet would, given the [before] position it
/// is played in.
///
/// Standard algebraic notation: the piece letter, only as much of the
/// starting square as is needed to tell it from another piece that could go
/// there, `x` for a capture, the destination, and `+` or `#` for what it does
/// to the other king.
///
/// It needs the position because the notation is not a property of the move.
/// `Nf3` is only `Nf3` while there is one knight that can reach f3; with two,
/// the same move is written `Ngf3`. This is the whole reason notation lives
/// here rather than on [Move].
String describeMove(Position before, Move move) {
  final buffer = StringBuffer();
  if (move.kind == MoveKind.castleKingside) {
    buffer.write('O-O');
  } else if (move.kind == MoveKind.castleQueenside) {
    buffer.write('O-O-O');
  } else if (move.moved == PieceKind.pawn) {
    // A pawn capture names the file it left, and a pawn push names nothing
    // but where it arrived.
    if (move.isCapture) buffer.write('${move.from.file}x');
    buffer.write(move.to.name);
    if (move.promotion != null) buffer.write('=${move.promotion!.letter}');
  } else {
    buffer
      ..write(move.moved.letter)
      ..write(_disambiguate(before, move));
    if (move.isCapture) buffer.write('x');
    buffer.write(move.to.name);
  }

  final after = before.makeMove(move);
  if (after.isCheckmate) {
    buffer.write('#');
  } else if (after.inCheck) {
    buffer.write('+');
  }
  return buffer.toString();
}

/// As much of [move]'s starting square as the reader needs.
///
/// Nothing when no other piece of the same kind can make the same move; the
/// file when that tells them apart; the rank when it does not; and the whole
/// square in the position that needs it — three queens on the same file and
/// rank as each other is rare, and is exactly when notation stops being able
/// to shorten anything.
String _disambiguate(Position before, Move move) {
  final rivals = before.legalMoves.where(
    (Move other) =>
        other.moved == move.moved &&
        other.to == move.to &&
        other.from != move.from,
  );
  if (rivals.isEmpty) return '';
  final files = rivals.map((Move other) => other.from.col);
  final ranks = rivals.map((Move other) => other.from.row);
  if (!files.contains(move.from.col)) return move.from.file;
  if (!ranks.contains(move.from.row)) return '${move.from.rank}';
  return move.from.name;
}

/// Reads a move written as UCI, such as `e2e4` or `e7e8q`, against the
/// [position] it was played in.
///
/// Returns `null` when the text is not a move or the move is not legal there,
/// which is what a save written by an older version comes back as.
Move? parseUci(Position position, String uci) {
  if (uci.length < 4 || uci.length > 5) return null;
  final from = Square.tryParse(uci.substring(0, 2));
  final to = Square.tryParse(uci.substring(2, 4));
  if (from == null || to == null) return null;
  PieceKind? promotion;
  if (uci.length == 5) {
    final letter = uci[4].toUpperCase();
    for (final kind in PieceKind.promotions) {
      if (kind.letter == letter) promotion = kind;
    }
    if (promotion == null) return null;
  }
  return position.findMove(from, to, promotion: promotion);
}
