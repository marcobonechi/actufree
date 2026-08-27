import 'candidate_grid.dart';
import 'cell.dart';
import 'deduction.dart';
import 'difficulty.dart';
import 'hint.dart';
import 'logic.dart';
import 'rating.dart';
import 'search.dart';
import 'sudoku_board.dart';
import 'tables.dart';
import 'technique.dart';
import 'techniques.dart';

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
  SolveResult solve(SudokuBoard board) {
    final grid = _gridOf(board);
    if (grid == null) return const Unsolvable();
    final counts = <Technique, int>{};
    if (!runLogic(grid, counts)) return const Unsolvable();
    if (grid.isSolved) {
      return Solved(_fill(board, grid), ratingFrom(counts));
    }
    if (!allowGuessing) return const Unsolvable();
    final search = SolutionSearch(limit: 1)..run(grid);
    final solution = search.solution;
    if (solution == null) return const Unsolvable();
    counts.update(Technique.guess, (value) => value + 1, ifAbsent: () => 1);
    return Solved(_fill(board, solution), ratingFrom(counts));
  }

  /// Counts solutions, stopping once [limit] have been found.
  ///
  /// The default limit of two is all uniqueness checking needs, and stopping
  /// early is what keeps generation fast.
  int countSolutions(SudokuBoard board, {int limit = 2}) {
    final grid = _gridOf(board);
    if (grid == null) return 0;
    final search = SolutionSearch(limit: limit)..run(grid);
    return search.solutionCount;
  }

  /// Whether [board] has exactly one solution.
  bool hasUniqueSolution(SudokuBoard board) => countSolutions(board) == 1;

  /// Rates [board] by the techniques needed to solve it.
  ///
  /// Ignores [allowGuessing]: rating a puzzle means finding out whether logic
  /// alone suffices, so a board that stalls is rated [Difficulty.expert]
  /// rather than reported as unsolvable.
  ///
  /// Throws [ArgumentError] when [board] has no solution at all.
  DifficultyRating rate(SudokuBoard board) {
    final grid = _gridOf(board);
    if (grid == null) throw _noSolution(board);
    final counts = <Technique, int>{};
    if (!runLogic(grid, counts)) throw _noSolution(board);
    if (grid.isSolved) return ratingFrom(counts);
    final search = SolutionSearch(limit: 1)..run(grid);
    if (search.solution == null) throw _noSolution(board);
    counts.update(Technique.guess, (value) => value + 1, ifAbsent: () => 1);
    return ratingFrom(counts);
  }

  /// The next logical step available on [board], or `null` when none is —
  /// either because the board is finished, is contradictory, or needs a
  /// technique beyond those implemented.
  ///
  /// Prefers a placement over an elimination, and the most elementary
  /// technique that yields one, so the hint matches what a player would
  /// plausibly spot next.
  Hint? nextHint(SudokuBoard board) {
    final grid = _gridOf(board);
    if (grid == null || grid.isSolved) return null;
    for (final finder in orderedFinders) {
      final deduction = finder.find(grid);
      if (deduction != null) return _hintFrom(deduction);
    }
    return null;
  }

  static ArgumentError _noSolution(SudokuBoard board) =>
      ArgumentError.value(board.toCompactString(), 'board', 'has no solution');

  static CandidateGrid? _gridOf(SudokuBoard board) {
    final placed = List<int>.filled(cellCount, 0);
    for (final cell in Cell.all) {
      placed[cell.index] = board.valueAt(cell) ?? 0;
    }
    return CandidateGrid.fromDigits(placed);
  }

  static SudokuBoard _fill(SudokuBoard board, CandidateGrid grid) {
    var result = board;
    for (final cell in board.emptyCells) {
      result = result.withValue(cell, grid.values[cell.index]);
    }
    return result;
  }

  static Hint _hintFrom(Deduction deduction) {
    final because = deduction.because.map(Cell.fromIndex).toSet();
    final index = deduction.placementIndex;
    if (index != null) {
      return PlacementHint(
        technique: deduction.technique,
        explanation: deduction.explanation,
        cell: Cell.fromIndex(index),
        digit: deduction.placementDigit!,
        because: because,
      );
    }
    return EliminationHint(
      technique: deduction.technique,
      explanation: deduction.explanation,
      eliminations: <Cell, Set<int>>{
        for (final entry in deduction.eliminations.entries)
          Cell.fromIndex(entry.key): digitsOf(entry.value).toSet(),
      },
      because: because,
    );
  }
}
