import 'cell.dart';
import 'sudoku_board.dart';

/// Why a move could not be made.
enum MoveRejection {
  /// The target cell holds a clue.
  cellIsGiven('That square is part of the puzzle'),

  /// The digit was outside 1-9.
  digitOutOfRange('Not a digit'),

  /// The digit already appears in the cell's row, column or box.
  conflictsWithPeer('That digit is already in this row, column or box');

  const MoveRejection(this.message);

  /// A short human-readable explanation.
  final String message;
}

/// The result of asking whether a move may be made.
sealed class MoveResult {
  const MoveResult();
}

/// The move is legal. [board] is the board with the move applied.
final class MoveAccepted extends MoveResult {
  const MoveAccepted(this.board);

  /// The resulting board.
  final SudokuBoard board;
}

/// The move is not legal and was not applied.
final class MoveRejected extends MoveResult {
  const MoveRejected(this.reason, this.culprits);

  /// Why the move was refused.
  final MoveRejection reason;

  /// For [MoveRejection.conflictsWithPeer], the cells already holding the
  /// digit. Empty otherwise.
  final Set<Cell> culprits;
}

/// Decides whether player moves are allowed.
///
/// [strict] refuses any move that conflicts with a peer. A lenient validator
/// accepts the move and lets the player see the conflict on the board, which
/// is how most Sudoku apps behave.
final class MoveValidator {
  /// Creates a validator.
  const MoveValidator({this.strict = false});

  /// Whether conflicting entries are refused rather than applied.
  final bool strict;

  /// Whether writing [digit] into [cell] is allowed, and the board that
  /// results if it is.
  ///
  /// A `null` [digit] clears the cell and is always allowed unless the cell is
  /// a given.
  MoveResult apply(SudokuBoard board, Cell cell, int? digit) =>
      throw UnimplementedError();
}
