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

  /// Generates a puzzle for [target].
  ///
  /// A tier is a promise about the shape of the puzzle: how many clues it
  /// starts with, and the band of reasoning it asks for. It is not a promise
  /// that every puzzle needs the tier's hardest technique — see
  /// [SudokuPuzzle.difficulty]. [SudokuPuzzle.rating] measures what solving it
  /// actually takes.
  ///
  /// One carve costs a few milliseconds, and not every grid can be carved into
  /// a puzzle that demands the upper tiers' reasoning, so unsuccessful carves
  /// are simply retried. After [maxAttempts] the closest one found is
  /// returned rather than looping on an unlucky seed.
  SudokuPuzzle generate(Difficulty target, {int maxAttempts = 60}) {
    if (maxAttempts < 1) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be positive');
    }
    final demands = _shapeOf(target).demands;
    final source = Random(seed);
    SudokuPuzzle? best;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final solved = _solvedGrid(Random(source.nextInt(_seedSpace)));
      final puzzle = _carve(solved, target, Random(source.nextInt(_seedSpace)));
      if (demands == null || puzzle.rating.tier.index >= demands.index) {
        return puzzle;
      }
      if (best == null ||
          puzzle.rating.tier.index > best.rating.tier.index ||
          (puzzle.rating.tier == best.rating.tier &&
              puzzle.rating.score > best.rating.score)) {
        best = puzzle;
      }
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
    // Carving as far as uniqueness allows lands every tier near the minimum,
    // and a 24-clue grid is tedious even when every step is a naked single —
    // the work is in hunting for the cell, not in the deduction. The floor is
    // what actually separates an easy puzzle from an expert one for a player;
    // the technique ceiling only decides what kind of thinking is required.
    // Two phases, both driven by the same loop. Down to the clue floor, remove
    // whatever uniqueness and the ceiling allow. At the floor, stop as soon as
    // the puzzle genuinely demands the target tier — and if it does not, keep
    // removing past the floor until it does. The result carries as many clues
    // as the tier can bear, which is the difference between an easy puzzle
    // that flows and one that is technically easy but tedious to search.
    final shape = _shapeOf(target);
    var clues = cellCount;
    for (final index in order) {
      final clue = working[index];
      if (clue == 0) continue;
      // Stop once the puzzle has both few enough clues and enough to think
      // about. Clue count alone makes every tier a search exercise; a required
      // technique alone drags the middle tiers sparser than the top ones,
      // because forcing a naked pair means stripping the grid until singles
      // run out. Upper tiers carve past the floor until the reasoning demand
      // is met.
      if (clues <= shape.floor && _demandMet(working, shape.demands)) break;
      working[index] = 0;
      if (!_isUnique(working) || !_withinCeiling(working, ceiling)) {
        working[index] = clue;
      } else {
        clues--;
      }
    }
    final givens = _boardOf(working);
    return SudokuPuzzle(
      givens: givens,
      solution: _boardOf(solved),
      difficulty: target,
      rating: const SudokuSolver().rate(givens),
      seed: seed,
    );
  }

  /// What a tier promises: how many clues to leave, and the least advanced
  /// technique the puzzle must end up requiring.
  ///
  /// The lower tiers set no reasoning demand — an easy puzzle is allowed to be
  /// nothing but naked singles, which is the point of it. The upper tiers do,
  /// because at 26 clues a puzzle that happened to need only singles would be
  /// a long slog rather than a hard one.
  static ({int floor, Difficulty? demands}) _shapeOf(Difficulty target) {
    switch (target) {
      case Difficulty.easy:
        return (floor: 42, demands: null);
      case Difficulty.medium:
        return (floor: 32, demands: null);
      case Difficulty.hard:
        return (floor: 28, demands: Difficulty.medium);
      case Difficulty.expert:
        return (floor: 26, demands: Difficulty.hard);
    }
  }

  /// Whether [values] already requires reasoning of at least [demands].
  static bool _demandMet(Int8List values, Difficulty? demands) {
    if (demands == null) return true;
    final grid = CandidateGrid.fromDigits(values);
    if (grid == null) return false;
    final counts = <Technique, int>{};
    if (!runLogic(grid, counts) || !grid.isSolved) return false;
    return ratingFrom(counts).tier.index >= demands.index;
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
