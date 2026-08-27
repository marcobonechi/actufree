import 'dart:math';
import 'dart:typed_data';

import 'candidate_grid.dart';
import 'cell.dart';
import 'difficulty.dart';
import 'logic.dart';
import 'puzzle.dart';
import 'rating.dart';
import 'search.dart';
import 'solver.dart';
import 'sudoku_board.dart';
import 'technique.dart';

/// Produces puzzles with a guaranteed unique solution.
///
/// The approach is the standard one: fill a grid completely, then remove clues
/// one at a time, putting any clue back whose removal would allow a second
/// solution.
final class SudokuGenerator {
  /// A generator seeded from [seed].
  ///
  /// The same seed always yields the same puzzle for the same target
  /// difficulty, so a bug report only needs to carry the seed.
  const SudokuGenerator(this.seed);

  /// The seed driving every random choice.
  final int seed;

  /// The range attempt seeds are drawn from; `Random.nextInt` tops out here.
  static const int _seedSpace = 1 << 32;

  /// Generates a puzzle rated [target].
  ///
  /// Removal is attempted until the puzzle's rating reaches [target] and no
  /// further clue can go without either losing uniqueness or overshooting the
  /// tier. Falls back to the closest tier reached after [maxAttempts] full
  /// grids, rather than looping forever on an unlucky seed.
  ///
  /// A single carve lands on the requested tier well under half the time for
  /// the upper tiers — puzzles that genuinely require a swordfish or a
  /// colouring chain are uncommon among minimal grids — so the budget covers
  /// many attempts. In practice every tier lands on target with a worst case
  /// around a tenth of a second.
  ///
  /// No generated puzzle ever requires a guess: see [_carve].
  SudokuPuzzle generate(Difficulty target, {int maxAttempts = 100}) {
    if (maxAttempts < 1) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be positive');
    }
    // Attempt seeds are drawn from one stream rooted at `seed` rather than
    // being `seed + attempt`: that would make seed 1's second attempt identical
    // to seed 2's first, so neighbouring seeds could hand back the same puzzle.
    final source = Random(seed);
    SudokuPuzzle? best;
    var bestDistance = 1 << 30;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final solved = _solvedGrid(Random(source.nextInt(_seedSpace)));
      final puzzle = _carve(solved, target, Random(source.nextInt(_seedSpace)));
      final distance = (puzzle.rating.tier.index - target.index).abs();
      if (distance == 0) return puzzle;
      if (distance >= bestDistance) continue;
      bestDistance = distance;
      best = puzzle;
    }
    return best!;
  }

  /// Generates a complete, valid, conflict-free grid.
  ///
  /// Exposed mainly for tests and for callers that want to build their own
  /// removal strategy.
  SudokuBoard generateSolvedGrid() => _boardOf(_solvedGrid(Random(seed)));

  /// Fills an empty grid by searching with the digit order shuffled.
  static Int8List _solvedGrid(Random random) {
    final search = SolutionSearch(limit: 1, random: random)
      ..run(CandidateGrid.empty());
    final solution = search.solution;
    if (solution == null) {
      throw StateError('an empty grid always has a solution');
    }
    return solution.values;
  }

  SudokuPuzzle _carve(Int8List solved, Difficulty target, Random random) {
    final working = Int8List.fromList(solved);
    final order = List<int>.generate(cellCount, (index) => index)
      ..shuffle(random);
    // Guessing is never allowed, at any tier. A puzzle that cannot be reasoned
    // out is a worse puzzle, not a harder one, so `expert` means "needs the
    // most advanced technique implemented" rather than "needs trial and
    // error". This also keeps the hint button useful on every generated
    // puzzle.
    final ceiling = techniquesUpTo(target).toSet()..remove(Technique.guess);
    for (final index in order) {
      final clue = working[index];
      if (clue == 0) continue;
      working[index] = 0;
      if (!_isUnique(working) || !_withinCeiling(working, ceiling)) {
        working[index] = clue;
      }
    }
    final givens = _boardOf(working);
    return SudokuPuzzle(
      givens: givens,
      solution: _boardOf(solved),
      rating: const SudokuSolver().rate(givens),
      seed: seed,
    );
  }

  static bool _isUnique(Int8List values) {
    final grid = CandidateGrid.fromDigits(values);
    if (grid == null) return false;
    final search = SolutionSearch()..run(grid);
    return search.solutionCount == 1;
  }

  static bool _withinCeiling(Int8List values, Set<Technique> ceiling) {
    final grid = CandidateGrid.fromDigits(values);
    if (grid == null) return false;
    if (!runLogic(grid, <Technique, int>{}, allowed: ceiling)) return false;
    return grid.isSolved;
  }

  static SudokuBoard _boardOf(Int8List values) => SudokuBoard.fromGivens(
        List<int?>.generate(
          cellCount,
          (index) => values[index] == 0 ? null : values[index],
        ),
      );
}
