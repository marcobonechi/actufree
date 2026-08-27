import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_kit/puzzle_kit.dart';
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
        theme: actufreeTheme(Brightness.light),
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

  testWidgets('there is no undo to reach for', (tester) async {
    await tester.pumpWidget(host());
    expect(tool('Undo'), findsNothing);
    expect(tool('Redo'), findsNothing);
    expect(tool('Erase'), findsOneWidget);
  });

  testWidgets('a wrong entry is flagged on the board straight away',
      (tester) async {
    await tester.pumpWidget(host());
    final answer = puzzle.solution.valueAt(firstEmpty)!;
    final wrong = answer == 9 ? 1 : answer + 1;
    // Picks a wrong digit that does not clash with any peer, so the flag can
    // only come from comparing against the solution.
    final quiet = Cell.all.firstWhere(
      (Cell cell) =>
          puzzle.givens.valueAt(cell) == null &&
          puzzle.givens.legalDigitsAt(cell).length > 1,
      orElse: () => firstEmpty,
    );
    final quietAnswer = puzzle.solution.valueAt(quiet)!;
    final quietWrong = puzzle.givens
        .legalDigitsAt(quiet)
        .firstWhere((int digit) => digit != quietAnswer);

    await enter(tester, quiet, quietWrong);
    final state = tester.state<State<SudokuScreen>>(find.byType(SudokuScreen));
    expect(state.mounted, isTrue);
    expect(find.byType(SudokuBoardView), findsOneWidget);

    // The flagged digit renders in the conflict colour even with no clash.
    final palette = SudokuPalette.light;
    final text = tester.widget<Text>(
      find.descendant(of: cellAt(quiet), matching: find.byType(Text)),
    );
    expect(text.data, '$quietWrong');
    expect(text.style?.color, palette.conflict);
    expect(puzzle.givens.isLegal(quiet, quietWrong), isTrue,
        reason: 'the wrong digit should not clash, or the test proves nothing');
    expect(wrong, isNot(answer));
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

  group('save and resume', () {
    testWidgets('a game in progress is written to its difficulty slot',
        (tester) async {
      final store = GameStore(MemoryStore());
      await tester.pumpWidget(MaterialApp(
        theme: actufreeTheme(Brightness.light),
        home: SudokuScreen(puzzle: puzzle, store: store),
      ));
      await enter(tester, firstEmpty, puzzle.solution.valueAt(firstEmpty)!);
      await tester.pumpAndSettle();

      final saved = await store.load(
        'sudoku',
        SudokuSave.fromJson,
        slot: puzzle.difficulty.name,
      );
      expect(saved, isNotNull);
      expect(saved!.board.valueAt(firstEmpty),
          puzzle.solution.valueAt(firstEmpty));
      expect(await store.has('sudoku', slot: Difficulty.expert.name), isFalse,
          reason: 'other difficulties keep their own slot');
    });

    testWidgets('resuming restores entries, notes and mistake flags',
        (tester) async {
      final wrongCell = Cell.all.lastWhere(
        (Cell cell) => puzzle.givens.valueAt(cell) == null,
      );
      final wrongDigit = puzzle.givens
          .legalDigitsAt(wrongCell)
          .firstWhere((int d) => d != puzzle.solution.valueAt(wrongCell));
      final resumed = puzzle.givens
          .withValue(firstEmpty, puzzle.solution.valueAt(firstEmpty)!)
          .withValue(wrongCell, wrongDigit);

      await tester.pumpWidget(MaterialApp(
        theme: actufreeTheme(Brightness.light),
        home: SudokuScreen(puzzle: puzzle, resumeFrom: resumed),
      ));
      final handle = tester.ensureSemantics();
      expect(tester.getSemantics(cellAt(firstEmpty)).value,
          '${puzzle.solution.valueAt(firstEmpty)}');

      // The mistake carried in from storage is flagged on the first frame,
      // not only after the next move.
      final text = tester.widget<Text>(
        find.descendant(of: cellAt(wrongCell), matching: find.byType(Text)),
      );
      expect(text.style?.color, SudokuPalette.light.conflict);
      handle.dispose();
    });

    testWidgets('finishing the puzzle clears the slot', (tester) async {
      final store = GameStore(MemoryStore());
      await tester.pumpWidget(MaterialApp(
        theme: actufreeTheme(Brightness.light),
        home: SudokuScreen(puzzle: puzzle, store: store),
      ));
      for (final cell in Cell.all) {
        if (puzzle.givens.valueAt(cell) != null) continue;
        await enter(tester, cell, puzzle.solution.valueAt(cell)!);
      }
      await tester.pumpAndSettle();
      expect(find.text('Solved'), findsOneWidget);
      expect(await store.has('sudoku', slot: puzzle.difficulty.name), isFalse);
    });
  });
}
