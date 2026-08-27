import 'package:sudoku_engine/sudoku_engine.dart';
import 'package:test/test.dart';

import 'puzzles.dart';

void main() {
  const solver = SudokuSolver();

  test('the first hint on an easy puzzle is a naked single', () {
    final hint = solver.nextHint(SudokuBoard.parse(easyPuzzle));
    expect(hint, isA<PlacementHint>());
    expect(hint!.technique, Technique.nakedSingle);
    expect(hint.explanation, isNotEmpty);
  });

  test('a placement hint highlights the cells that justify it', () {
    final hint = solver.nextHint(SudokuBoard.parse(easyPuzzle))!;
    expect(hint, isA<PlacementHint>());
    final placement = hint as PlacementHint;
    expect(placement.because, isNotEmpty);
    expect(placement.because, isNot(contains(placement.cell)));
    expect(placement.digit, inInclusiveRange(1, boardSize));
  });

  test('following hints alone solves a singles-only puzzle', () {
    var board = SudokuBoard.parse(easyPuzzle);
    var steps = 0;
    while (!board.isSolved && steps++ < cellCount + 1) {
      final hint = solver.nextHint(board);
      expect(hint, isA<PlacementHint>(), reason: 'stalled after $steps steps');
      final placement = hint! as PlacementHint;
      board = board.withValue(placement.cell, placement.digit);
    }
    expect(board.isSolved, isTrue);
    expect(board.toCompactString(), easySolution);
  });

  test('there is nothing to hint on a finished board', () {
    expect(solver.nextHint(SudokuBoard.parse(easySolution)), isNull);
  });

  test('there is nothing to hint on a contradictory board', () {
    expect(solver.nextHint(SudokuBoard.parse(contradictoryPuzzle)), isNull);
  });

  test('a puzzle beyond the technique set eventually runs out of hints', () {
    var board = SudokuBoard.parse(backtrackingPuzzle);
    var steps = 0;
    Hint? last;
    while (steps++ < cellCount * 2) {
      final hint = solver.nextHint(board);
      if (hint == null) break;
      last = hint;
      if (hint is! PlacementHint) break;
      board = board.withValue(hint.cell, hint.digit);
    }
    expect(board.isSolved, isFalse);
    expect(last, anyOf(isNull, isA<EliminationHint>()));
  });

  group('hints never lie', () {
    test('every deduction agrees with the puzzle\'s true solution', () {
      var placements = 0;
      var eliminations = 0;
      final techniques = <Technique>{};
      for (final difficulty in Difficulty.values) {
        for (var seed = 0; seed < 12; seed++) {
          final puzzle = SudokuGenerator(seed).generate(difficulty);
          var board = puzzle.givens;
          var steps = 0;
          while (steps++ < cellCount * 2) {
            final hint = solver.nextHint(board);
            if (hint == null) break;
            techniques.add(hint.technique);
            if (hint is PlacementHint) {
              placements++;
              // A wrong placement would contradict the unique solution.
              expect(hint.digit, puzzle.solution.valueAt(hint.cell),
                  reason: '${hint.technique} put ${hint.digit} in '
                      '${hint.cell} of $difficulty seed $seed');
              board = board.withValue(hint.cell, hint.digit);
              continue;
            }
            final elimination = hint as EliminationHint;
            eliminations++;
            for (final entry in elimination.eliminations.entries) {
              // Ruling out the true digit would be a broken technique.
              expect(entry.value,
                  isNot(contains(puzzle.solution.valueAt(entry.key))),
                  reason: '${hint.technique} ruled out the answer at '
                      '${entry.key} of $difficulty seed $seed');
            }
            // Eliminations cannot be written back to a board, which only
            // stores digits, so this is as far as hint-following goes.
            break;
          }
        }
      }
      expect(placements, greaterThan(500));
      expect(eliminations, greaterThan(0));
      expect(techniques, contains(Technique.nakedSingle));
      expect(techniques, contains(Technique.hiddenSingle));
    });
  });
}
