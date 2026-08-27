import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles_app/sudoku/board_view.dart';
import 'package:puzzles_app/sudoku/sudoku_game.dart';
import 'package:puzzles_app/sudoku/sudoku_screen.dart';
import 'package:puzzles_app/theme.dart';
import 'package:sudoku_engine/sudoku_engine.dart';

void main() {
  final SudokuPuzzle puzzle =
      const SudokuGenerator(2024).generate(Difficulty.easy);

  /// Fills every cell of [unit] except [leave].
  SudokuBoard fillUnit(List<Cell> unit, {required Cell leave}) {
    var board = puzzle.givens;
    for (final cell in unit) {
      if (cell == leave || board.isGiven(cell)) continue;
      board = board.withValue(cell, puzzle.solution.valueAt(cell)!);
    }
    return board;
  }

  group('completion detection', () {
    test('finishing a row announces it once', () {
      final row = allUnits.first;
      final gap = row.firstWhere((Cell cell) => !puzzle.givens.isGiven(cell));
      final game = SudokuGame(puzzle, board: fillUnit(row, leave: gap));

      expect(game.justCompleted, isEmpty);
      final before = game.completionTick;

      game
        ..select(gap)
        ..enter(puzzle.solution.valueAt(gap)!);

      expect(game.completionTick, before + 1);
      expect(game.justCompleted, containsAll(row));

      // The next move is not another completion.
      final elsewhere = Cell.all.firstWhere((Cell cell) =>
          !row.contains(cell) && puzzle.givens.valueAt(cell) == null);
      game
        ..select(elsewhere)
        ..enter(puzzle.solution.valueAt(elsewhere)!);
      expect(game.justCompleted, isEmpty);
      expect(game.completionTick, before + 1);
    });

    test('a row filled with a repeat is not a completion', () {
      final row = allUnits.first;
      final gaps =
          row.where((Cell cell) => !puzzle.givens.isGiven(cell)).toList();
      var board = puzzle.givens;
      for (final cell in gaps) {
        board = board.withValue(cell, puzzle.solution.valueAt(gaps.first)!);
      }
      final game = SudokuGame(puzzle, board: board);
      expect(game.justCompleted, isEmpty);
      expect(game.completionTick, 0);
    });

    test('resuming a game with finished units announces nothing', () {
      final row = allUnits.first;
      var board = puzzle.givens;
      for (final cell in row) {
        if (board.isGiven(cell)) continue;
        board = board.withValue(cell, puzzle.solution.valueAt(cell)!);
      }
      // The player finished this row last session; they do not need
      // congratulating again on launch.
      final game = SudokuGame(puzzle, board: board);
      expect(game.justCompleted, isEmpty);
      expect(game.completionTick, 0);
    });

    test('one move can finish a row, a column and a box at once', () {
      var board = puzzle.givens;
      final corner = Cell.all.firstWhere(
        (Cell cell) => puzzle.givens.valueAt(cell) == null,
      );
      for (final unit in corner.units) {
        for (final cell in unit) {
          if (cell == corner || board.isGiven(cell)) continue;
          board = board.withValue(cell, puzzle.solution.valueAt(cell)!);
        }
      }
      final game = SudokuGame(puzzle, board: board)
        ..select(corner)
        ..enter(puzzle.solution.valueAt(corner)!);

      expect(game.completionTick, 1);
      for (final unit in corner.units) {
        expect(game.justCompleted, containsAll(unit));
      }
    });
  });

  group('completion animation', () {
    testWidgets('a finished row flashes, then settles', (tester) async {
      final row = allUnits.first;
      final gap = row.firstWhere((Cell cell) => !puzzle.givens.isGiven(cell));

      await tester.pumpWidget(MaterialApp(
        theme: actufreeTheme(Brightness.light),
        home: SudokuScreen(
          puzzle: puzzle,
          resumeFrom: fillUnit(row, leave: gap),
        ),
      ));
      expect(find.byType(SudokuBoardView), findsOneWidget);

      await tester.tap(find.byKey(ValueKey<String>('cell-${gap.index}')));
      await tester.pump();
      await tester.tap(
        find.byKey(ValueKey<String>('digit-${puzzle.solution.valueAt(gap)}')),
      );
      await tester.pump();

      // Mid-flight the flash is being painted...
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      // ...and once it finishes, the board is back to its resting state.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SudokuBoardView), findsOneWidget);
    });
  });

  group('the Fill affordance', () {
    test('leaves exactly one cell, selected, and corrects mistakes', () {
      final game = SudokuGame(puzzle);
      final wrongAt = Cell.all.firstWhere(
        (Cell cell) => puzzle.givens.valueAt(cell) == null,
      );
      final answer = puzzle.solution.valueAt(wrongAt)!;
      game
        ..select(wrongAt)
        ..enter(answer == 9 ? 1 : answer + 1);
      expect(game.mistakes, isNotEmpty);

      game.autocomplete();

      expect(game.board.emptyCells, hasLength(1));
      expect(game.selected, game.board.emptyCells.single);
      expect(game.mistakes, isEmpty, reason: 'a wrong entry should be fixed');
      expect(game.isSolved, isFalse);
      // The bulk fill is silent; the player's last digit is what flashes.
      expect(game.justCompleted, isEmpty);
    });

    testWidgets('one tap after Fill flashes and then wins', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: actufreeTheme(Brightness.light),
        home: SudokuScreen(puzzle: puzzle),
      ));
      await tester.tap(find.byKey(const ValueKey<String>('tool-Fill')));
      await tester.pump();

      final remaining = Cell.all.firstWhere(
        (Cell cell) =>
            puzzle.givens.valueAt(cell) == null &&
            tester
                    .widget<SudokuScreen>(find.byType(SudokuScreen))
                    .puzzle
                    .solution
                    .valueAt(cell) !=
                null &&
            find
                .descendant(
                  of: find.byKey(ValueKey<String>('cell-${cell.index}')),
                  matching: find.byType(Text),
                )
                .evaluate()
                .isEmpty,
      );
      await tester.tap(
        find.byKey(
          ValueKey<String>('digit-${puzzle.solution.valueAt(remaining)}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Solved'), findsOneWidget);
    });
  });
}
