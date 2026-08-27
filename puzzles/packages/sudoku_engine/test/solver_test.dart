import 'package:sudoku_engine/sudoku_engine.dart';
import 'package:test/test.dart';

import 'puzzles.dart';

void main() {
  const solver = SudokuSolver();
  const logicOnly = SudokuSolver(allowGuessing: false);

  group('correctness', () {
    test('solves a known puzzle to its known solution', () {
      final result = solver.solve(SudokuBoard.parse(easyPuzzle));
      expect(result, isA<Solved>());
      expect((result as Solved).solution.toCompactString(), easySolution);
    });

    test('the solution keeps the original givens', () {
      final board = SudokuBoard.parse(easyPuzzle);
      final solved = (solver.solve(board) as Solved).solution;
      for (final cell in Cell.all) {
        if (!board.isGiven(cell)) continue;
        expect(solved.valueAt(cell), board.valueAt(cell));
        expect(solved.isGiven(cell), isTrue);
      }
    });

    test('solves a puzzle that needs backtracking', () {
      final board = SudokuBoard.parse(backtrackingPuzzle);
      final result = solver.solve(board);
      expect(result, isA<Solved>());
      final solved = result as Solved;
      expect(solved.solution.toCompactString(), backtrackingSolution);
      expect(solved.solution.isSolved, isTrue);
      expect(solved.rating.techniquesUsed, contains(Technique.guess));
    });

    test('without guessing, that same puzzle is reported unsolvable', () {
      final board = SudokuBoard.parse(backtrackingPuzzle);
      expect(logicOnly.solve(board), isA<Unsolvable>());
      // The puzzle is fine; it is the technique set that runs out.
      expect(solver.hasUniqueSolution(board), isTrue);
    });

    test('logic alone cracks a puzzle the technique set covers', () {
      final result = logicOnly.solve(SudokuBoard.parse(norvigHardPuzzle));
      expect(result, isA<Solved>());
      expect((result as Solved).solution.isSolved, isTrue);
      expect(result.rating.techniquesUsed, isNot(contains(Technique.guess)));
    });

    test('solving from a partly played board respects the entries', () {
      final board = SudokuBoard.parse(easyPuzzle).withValue(const Cell(0, 2), 4);
      final result = solver.solve(board);
      expect(result, isA<Solved>());
      expect((result as Solved).solution.toCompactString(), easySolution);
    });

    test('a wrong entry makes the board unsolvable', () {
      // r1c3 is 4 in the solution; 1 is legal against the givens but wrong.
      final board = SudokuBoard.parse(easyPuzzle).withValue(const Cell(0, 2), 1);
      expect(board.conflicts, isEmpty);
      expect(solver.solve(board), isA<Unsolvable>());
    });

    test('a contradictory board is unsolvable and has no solutions', () {
      final board = SudokuBoard.parse(contradictoryPuzzle);
      expect(solver.solve(board), isA<Unsolvable>());
      expect(solver.countSolutions(board), 0);
      expect(solver.hasUniqueSolution(board), isFalse);
    });

    test('an already-solved board comes back unchanged', () {
      final board = SudokuBoard.parse(easySolution);
      final result = solver.solve(board);
      expect(result, isA<Solved>());
      expect((result as Solved).solution.toCompactString(), easySolution);
    });
  });

  group('counting solutions', () {
    test('a proper puzzle has exactly one', () {
      final board = SudokuBoard.parse(easyPuzzle);
      expect(solver.countSolutions(board), 1);
      expect(solver.hasUniqueSolution(board), isTrue);
    });

    test('an under-constrained puzzle has more than one', () {
      final board = SudokuBoard.parse(ambiguousPuzzle);
      expect(solver.countSolutions(board), 2);
      expect(solver.hasUniqueSolution(board), isFalse);
    });

    test('the limit caps the work', () {
      final board = SudokuBoard.parse(ambiguousPuzzle);
      expect(solver.countSolutions(board, limit: 1), 1);
      expect(solver.countSolutions(board, limit: 5), 5);
    });

    test('an empty board is wildly ambiguous', () {
      expect(solver.countSolutions(SudokuBoard.empty(), limit: 3), 3);
    });
  });

  group('rating', () {
    test('a singles-only puzzle rates easy', () {
      final rating = solver.rate(SudokuBoard.parse(easyPuzzle));
      expect(rating.tier, Difficulty.easy);
      expect(rating.hardestTechnique, Technique.nakedSingle);
      expect(rating.techniquesUsed[Technique.nakedSingle], greaterThan(0));
      expect(rating.score, greaterThan(0));
    });

    test('a puzzle that stalls the technique set rates expert', () {
      final rating = solver.rate(SudokuBoard.parse(backtrackingPuzzle));
      expect(rating.tier, Difficulty.expert);
      expect(rating.hardestTechnique, Technique.guess);
    });

    test('rating ignores allowGuessing', () {
      final board = SudokuBoard.parse(backtrackingPuzzle);
      expect(logicOnly.rate(board).tier, Difficulty.expert);
    });

    test('techniquesUsed is ordered from easiest to hardest', () {
      final rating = solver.rate(SudokuBoard.parse(backtrackingPuzzle));
      final order = rating.techniquesUsed.keys.map((t) => t.index).toList();
      expect(order, orderedEquals(List<int>.of(order)..sort()));
    });

    test('the hardest technique is the last one used', () {
      final rating = solver.rate(SudokuBoard.parse(backtrackingPuzzle));
      expect(rating.hardestTechnique, rating.techniquesUsed.keys.last);
    });

    test('rating a board with no solution is an error', () {
      expect(() => solver.rate(SudokuBoard.parse(contradictoryPuzzle)),
          throwsArgumentError);
    });

    test('every technique maps to a tier and every tier has a label', () {
      for (final difficulty in Difficulty.values) {
        expect(difficulty.label, isNotEmpty);
      }
      for (final technique in Technique.values) {
        expect(technique.label, isNotEmpty);
      }
    });
  });
}
