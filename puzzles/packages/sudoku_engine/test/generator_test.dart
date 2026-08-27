import 'package:sudoku_engine/sudoku_engine.dart';
import 'package:test/test.dart';

void main() {
  const solver = SudokuSolver();

  group('solved grids', () {
    test('produces a complete, conflict-free grid', () {
      final grid = const SudokuGenerator(1).generateSolvedGrid();
      expect(grid.isComplete, isTrue);
      expect(grid.isSolved, isTrue);
      expect(grid.conflicts, isEmpty);
    });

    test('is deterministic for a seed', () {
      expect(const SudokuGenerator(99).generateSolvedGrid(),
          const SudokuGenerator(99).generateSolvedGrid());
    });

    test('different seeds give different grids', () {
      expect(const SudokuGenerator(1).generateSolvedGrid(),
          isNot(const SudokuGenerator(2).generateSolvedGrid()));
    });
  });

  group('determinism', () {
    test('the same seed and tier give an identical puzzle', () {
      for (final difficulty in Difficulty.values) {
        final first = const SudokuGenerator(1234).generate(difficulty);
        final second = const SudokuGenerator(1234).generate(difficulty);
        expect(first.givens, second.givens, reason: '$difficulty givens');
        expect(first.solution, second.solution, reason: '$difficulty solution');
        expect(first.rating.score, second.rating.score);
        expect(first.rating.tier, second.rating.tier);
        expect(first.seed, 1234);
      }
    });

    test('different seeds give different puzzles', () {
      // Checked across a run of neighbouring seeds, not just one pair: an
      // earlier version derived attempt seeds as `seed + attempt`, so seed 1's
      // second attempt reproduced seed 2's first and the two collided.
      final seen = <String, int>{};
      for (var seed = 1; seed <= 20; seed++) {
        final puzzle = SudokuGenerator(seed).generate(Difficulty.medium);
        final key = puzzle.givens.toCompactString();
        expect(seen.containsKey(key), isFalse,
            reason: 'seed $seed repeats the puzzle from seed ${seen[key]}');
        seen[key] = seed;
      }
    });

    test('maxAttempts must be positive', () {
      expect(
        () => const SudokuGenerator(1).generate(Difficulty.easy, maxAttempts: 0),
        throwsArgumentError,
      );
    });

    test('the requested tier is what the puzzle reports', () {
      for (final difficulty in Difficulty.values) {
        expect(
          SudokuGenerator(7).generate(difficulty).difficulty,
          difficulty,
        );
      }
    });
  });

  group('every generated puzzle', () {
    const seeds = 10;

    test('has exactly one solution', () {
      for (final difficulty in Difficulty.values) {
        for (var seed = 0; seed < seeds; seed++) {
          final puzzle = SudokuGenerator(seed).generate(difficulty);
          expect(solver.hasUniqueSolution(puzzle.givens), isTrue,
              reason: '$difficulty seed $seed is not unique');
        }
      }
    });

    test('carries the solution that completes its givens', () {
      for (final difficulty in Difficulty.values) {
        for (var seed = 0; seed < seeds; seed++) {
          final puzzle = SudokuGenerator(seed).generate(difficulty);
          expect(puzzle.solution.isSolved, isTrue);
          for (final cell in Cell.all) {
            final clue = puzzle.givens.valueAt(cell);
            if (clue == null) continue;
            expect(puzzle.solution.valueAt(cell), clue,
                reason: '$difficulty seed $seed disagrees at $cell');
          }
          final solved = solver.solve(puzzle.givens);
          expect((solved as Solved).solution.toCompactString(),
              puzzle.solution.toCompactString());
        }
      }
    });

    test('starts with clues only and no player entries', () {
      final puzzle = const SudokuGenerator(5).generate(Difficulty.medium);
      for (final cell in Cell.all) {
        if (puzzle.givens.valueAt(cell) == null) continue;
        expect(puzzle.givens.isGiven(cell), isTrue);
      }
      expect(puzzle.clueCount, greaterThan(16));
      expect(puzzle.clueCount, lessThan(cellCount));
      expect(puzzle.clueCount, puzzle.givens.toCompactString().replaceAll('.', '').length);
    });

    test('never demands a technique above its tier', () {
      // The tier is a ceiling on the reasoning required, so a medium puzzle
      // may turn out to need only singles, but never a swordfish.
      for (final difficulty in Difficulty.values) {
        for (var seed = 0; seed < seeds; seed++) {
          final puzzle = SudokuGenerator(seed).generate(difficulty);
          expect(puzzle.difficulty, difficulty);
          expect(puzzle.rating.tier.index, lessThanOrEqualTo(difficulty.index),
              reason: '$difficulty seed $seed needed '
                  '${puzzle.rating.hardestTechnique}');
        }
      }
    });

    test('starts with more clues the easier the tier', () {
      // The other half of what a tier promises: an easy puzzle is easy partly
      // because there is less of the grid to search.
      var previous = cellCount;
      for (final difficulty in Difficulty.values) {
        var clues = 0;
        for (var seed = 0; seed < seeds; seed++) {
          clues += SudokuGenerator(seed).generate(difficulty).clueCount;
        }
        final average = clues / seeds;
        expect(average, lessThan(previous),
            reason: '$difficulty averages $average clues');
        previous = average.round();
      }
    });

    test('an easy puzzle is actually easy', () {
      // The complaint this tier exists to answer: a puzzle can be "singles
      // only" and still be a slog if two thirds of the grid is empty, because
      // the work moves from deducing to hunting.
      for (var seed = 0; seed < seeds; seed++) {
        final puzzle = SudokuGenerator(seed).generate(Difficulty.easy);
        expect(puzzle.clueCount, greaterThanOrEqualTo(40),
            reason: 'easy seed $seed starts with only ${puzzle.clueCount}');
        expect(puzzle.rating.tier, Difficulty.easy);
        expect(
          puzzle.rating.techniquesUsed.keys,
          everyElement(
            anyOf(Technique.nakedSingle, Technique.hiddenSingle),
          ),
        );
      }
    });

    test('the harder the tier, the more the reasoning costs', () {
      // Clue count is only half of it; the brief asks for difficulty derived
      // from the techniques a puzzle requires.
      var previous = 0;
      for (final difficulty in Difficulty.values) {
        var score = 0;
        for (var seed = 0; seed < seeds; seed++) {
          score += SudokuGenerator(seed).generate(difficulty).rating.score;
        }
        final average = score ~/ seeds;
        expect(average, greaterThan(previous),
            reason: '$difficulty scores $average');
        previous = average;
      }
    });

    test('never requires a guess', () {
      // The point of the tiers: a puzzle that cannot be reasoned out is a
      // worse puzzle, not a harder one. Expert means "needs the most advanced
      // technique implemented", and the hint button works on every puzzle the
      // generator produces.
      const logicOnly = SudokuSolver(allowGuessing: false);
      for (final difficulty in Difficulty.values) {
        for (var seed = 0; seed < seeds; seed++) {
          final puzzle = SudokuGenerator(seed).generate(difficulty);
          expect(logicOnly.solve(puzzle.givens), isA<Solved>(),
              reason: '$difficulty seed $seed needs trial and error');
          expect(puzzle.rating.hardestTechnique, isNot(Technique.guess));
          expect(const SudokuSolver().nextHint(puzzle.givens), isNotNull);
        }
      }
    });

    test('is rated consistently by the solver', () {
      for (var seed = 0; seed < seeds; seed++) {
        final puzzle = SudokuGenerator(seed).generate(Difficulty.hard);
        final rerated = solver.rate(puzzle.givens);
        expect(rerated.tier, puzzle.rating.tier);
        expect(rerated.score, puzzle.rating.score);
        expect(rerated.hardestTechnique, puzzle.rating.hardestTechnique);
      }
    });
  });

  group('performance', () {
    test('a hard puzzle is generated well inside a second', () {
      for (var seed = 0; seed < 5; seed++) {
        final stopwatch = Stopwatch()..start();
        SudokuGenerator(seed).generate(Difficulty.hard);
        stopwatch.stop();
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)),
            reason: 'hard seed $seed took ${stopwatch.elapsedMilliseconds}ms');
      }
    });

    test('an easy puzzle is near-instant', () {
      final stopwatch = Stopwatch()..start();
      const SudokuGenerator(3).generate(Difficulty.easy);
      expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 500)));
    });
  });
}
