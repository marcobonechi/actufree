import 'difficulty.dart';
import 'hint.dart';
import 'sudoku_board.dart';

/// The outcome of a solve attempt.
sealed class SolveResult {
  const SolveResult();
}

/// The board has at least one solution.
final class Solved extends SolveResult {
  /// Creates a solved result.
  const Solved(this.solution, this.rating);

  /// The completed board.
  final SudokuBoard solution;

  /// Which techniques were needed to get there.
  final DifficultyRating rating;
}

/// The board has no solution — it contains a contradiction.
final class Unsolvable extends SolveResult {
  /// Creates an unsolvable result.
  const Unsolvable();
}

/// Solves boards by constraint propagation, falling back to backtracking.
///
/// The solver never looks at the player's pencil marks; it derives candidates
/// from the digits on the board.
final class SudokuSolver {
  /// Creates a solver.
  const SudokuSolver({this.allowGuessing = true});

  /// Whether the solver may backtrack when logic stalls.
  ///
  /// With this off, a puzzle the implemented techniques cannot crack comes
  /// back as [Unsolvable] even though a solution exists.
  final bool allowGuessing;

  /// Solves [board] from its current state.
  SolveResult solve(SudokuBoard board) => throw UnimplementedError();

  /// Counts solutions, stopping once [limit] have been found.
  ///
  /// The default limit of two is all uniqueness checking needs, and stopping
  /// early is what keeps generation fast.
  int countSolutions(SudokuBoard board, {int limit = 2}) =>
      throw UnimplementedError();

  /// Whether [board] has exactly one solution.
  bool hasUniqueSolution(SudokuBoard board) => throw UnimplementedError();

  /// Rates [board] by the techniques needed to solve it.
  DifficultyRating rate(SudokuBoard board) => throw UnimplementedError();

  /// The next logical step available on [board], or `null` when none is —
  /// either because the board is finished, is contradictory, or needs a
  /// technique beyond those implemented.
  ///
  /// Prefers a placement over an elimination, and the most elementary
  /// technique that yields one, so the hint matches what a player would
  /// plausibly spot next.
  Hint? nextHint(SudokuBoard board) => throw UnimplementedError();
}
