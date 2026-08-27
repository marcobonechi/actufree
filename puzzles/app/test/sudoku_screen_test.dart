import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles_app/sudoku/board_view.dart';
import 'package:puzzles_app/sudoku/sudoku_screen.dart';
import 'package:puzzles_app/theme.dart';
import 'package:sudoku_engine/sudoku_engine.dart';

void main() {
  // A fixed seed keeps these tests reading the same board every run.
  final SudokuPuzzle puzzle =
      const SudokuGenerator(2024).generate(Difficulty.easy);
  final Cell firstEmpty =
      Cell.all.firstWhere((Cell cell) => puzzle.givens.valueAt(cell) == null);
  final Cell firstGiven =
      Cell.all.firstWhere((Cell cell) => puzzle.givens.valueAt(cell) != null);

  Widget host() => MaterialApp(
        theme: buildTheme(Brightness.light),
        home: SudokuScreen(puzzle: puzzle),
      );

  Finder cellAt(Cell cell) => find.byKey(ValueKey<String>('cell-${cell.index}'));
  Finder digitKey(int digit) => find.byKey(ValueKey<String>('digit-$digit'));
  Finder tool(String label) => find.byKey(ValueKey<String>('tool-$label'));

  Future<void> enter(WidgetTester tester, Cell cell, int digit) async {
    await tester.tap(cellAt(cell));
    await tester.pump();
    await tester.tap(digitKey(digit));
    await tester.pump();
  }

  testWidgets('renders every cell and shows the clues', (tester) async {
    await tester.pumpWidget(host());
    final handle = tester.ensureSemantics();
    for (final cell in Cell.all) {
      expect(cellAt(cell), findsOneWidget);
    }
    expect(
      tester.getSemantics(cellAt(firstGiven)).value,
      '${puzzle.givens.valueAt(firstGiven)}',
    );
    expect(tester.getSemantics(cellAt(firstEmpty)).value, 'empty');
    handle.dispose();
  });

  testWidgets('tapping a cell then a digit writes it', (tester) async {
    await tester.pumpWidget(host());
    final handle = tester.ensureSemantics();
    final answer = puzzle.solution.valueAt(firstEmpty)!;
    await enter(tester, firstEmpty, answer);
    expect(tester.getSemantics(cellAt(firstEmpty)).value, '$answer');
    handle.dispose();
  });

  testWidgets('tapping the same digit again clears the cell', (tester) async {
    await tester.pumpWidget(host());
    final handle = tester.ensureSemantics();
    final answer = puzzle.solution.valueAt(firstEmpty)!;
    await enter(tester, firstEmpty, answer);
    await tester.tap(digitKey(answer));
    await tester.pump();
    expect(tester.getSemantics(cellAt(firstEmpty)).value, 'empty');
    handle.dispose();
  });

  testWidgets('a clue cannot be overwritten', (tester) async {
    await tester.pumpWidget(host());
    final handle = tester.ensureSemantics();
    final clue = puzzle.givens.valueAt(firstGiven)!;
    final other = clue == 1 ? 2 : 1;
    await enter(tester, firstGiven, other);
    expect(tester.getSemantics(cellAt(firstGiven)).value, '$clue');
    handle.dispose();
  });

  testWidgets('notes mode writes pencil marks instead of a value',
      (tester) async {
    await tester.pumpWidget(host());
    final handle = tester.ensureSemantics();
    await tester.tap(tool('Notes'));
    await tester.pump();
    await enter(tester, firstEmpty, 4);
    expect(tester.getSemantics(cellAt(firstEmpty)).value, 'empty');
    expect(
      find.descendant(of: cellAt(firstEmpty), matching: find.text('4')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('undo and redo walk the history', (tester) async {
    await tester.pumpWidget(host());
    final handle = tester.ensureSemantics();
    final answer = puzzle.solution.valueAt(firstEmpty)!;
    await enter(tester, firstEmpty, answer);
    await tester.tap(tool('Undo'));
    await tester.pump();
    expect(tester.getSemantics(cellAt(firstEmpty)).value, 'empty');
    await tester.tap(tool('Redo'));
    await tester.pump();
    expect(tester.getSemantics(cellAt(firstEmpty)).value, '$answer');
    handle.dispose();
  });

  testWidgets('erase clears the selected cell', (tester) async {
    await tester.pumpWidget(host());
    final handle = tester.ensureSemantics();
    await enter(tester, firstEmpty, puzzle.solution.valueAt(firstEmpty)!);
    await tester.tap(tool('Erase'));
    await tester.pump();
    expect(tester.getSemantics(cellAt(firstEmpty)).value, 'empty');
    handle.dispose();
  });

  testWidgets('the hint button fills a cell and explains itself',
      (tester) async {
    await tester.pumpWidget(host());
    final handle = tester.ensureSemantics();
    await tester.tap(tool('Hint'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    final filled = Cell.all.where((Cell cell) =>
        puzzle.givens.valueAt(cell) == null &&
        tester.getSemantics(cellAt(cell)).value != 'empty');
    expect(filled, hasLength(1));
    expect(
      puzzle.solution.valueAt(filled.single).toString(),
      tester.getSemantics(cellAt(filled.single)).value,
    );
    handle.dispose();
  });

  testWidgets('a wrong entry is reported before any further hint',
      (tester) async {
    await tester.pumpWidget(host());
    final answer = puzzle.solution.valueAt(firstEmpty)!;
    await enter(tester, firstEmpty, answer == 9 ? 1 : answer + 1);
    await tester.tap(tool('Hint'));
    await tester.pump();
    expect(find.text('Mistake'), findsOneWidget);
  });

  testWidgets('filling the grid correctly wins the game', (tester) async {
    await tester.pumpWidget(host());
    final handle = tester.ensureSemantics();
    for (final cell in Cell.all) {
      if (puzzle.givens.valueAt(cell) != null) continue;
      await enter(tester, cell, puzzle.solution.valueAt(cell)!);
    }
    await tester.pumpAndSettle();
    expect(find.text('Solved'), findsOneWidget);
    expect(find.text('Back to menu'), findsOneWidget);
    handle.dispose();
  });

  group('layout', () {
    // These sizes exercise the two branches of the responsive layout. An
    // overflow in either one fails the test on its own.
    testWidgets('puts the board beside the pad in landscape', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host());
      expect(find.byType(SudokuBoardView), findsOneWidget);
      expect(digitKey(1), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a small phone in portrait', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host());
      expect(find.byType(SudokuBoardView), findsOneWidget);
      for (final digit in digits) {
        expect(digitKey(digit), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  });
}
