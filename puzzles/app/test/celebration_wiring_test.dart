import 'dart:math';

import 'package:blockblast_engine/blockblast_engine.dart';
// Both engines call their eight-a-side board 'boardSize'.
import 'package:chess_engine/chess_engine.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_kit/puzzle_kit.dart';
import 'package:puzzles_app/blockblast/block_game.dart';
import 'package:puzzles_app/blockblast/block_screen.dart';
import 'package:puzzles_app/blockblast/board_view.dart';
import 'package:puzzles_app/blockblast/hand_tray.dart';
import 'package:puzzles_app/chess/chess_screen.dart';
import 'package:puzzles_app/sudoku/sudoku_screen.dart';
import 'package:puzzles_app/theme.dart';
import 'package:sudoku_engine/sudoku_engine.dart' as sudoku;

import 'blockblast_controller_test.dart' show gameWith;
import 'chess_match_test.dart' show firstLegalMove;

/// What a cue has been asked for, worked out by letting a field carry it out.
///
/// No layer is put up in these tests, so nothing drains the cue and what the
/// screen asked for is still sitting there to be inspected.
({int particles, int shells, bool fromBelow}) whatWasThrown(
  CelebrationCue cue,
) {
  final field = CelebrationField(random: Random(1));
  for (final request in cue.take()) {
    request(field);
  }
  return (
    particles: field.particles.length,
    // Fireworks put shells up rather than colour out: nothing exists until one
    // of them goes off, so the shells are how that request is recognised.
    shells: field.shells.length,
    // A fountain starts below the bottom edge and climbs in; a burst starts
    // where it was thrown from, which is always on the screen.
    fromBelow: field.particles.isNotEmpty &&
        field.particles.every((CelebrationParticle p) => p.position.dy > 1),
  );
}

Widget host(CelebrationCue cue, Widget child) => MaterialApp(
      theme: actufreeTheme(Brightness.light),
      home: CelebrationScope(cue: cue, child: child),
    );

void main() {
  group('Sudoku', () {
    final sudoku.SudokuPuzzle puzzle =
        const sudoku.SudokuGenerator(2024).generate(sudoku.Difficulty.easy);

    testWidgets('solving the puzzle throws colour across the screen', (
      tester,
    ) async {
      final cue = CelebrationCue();
      await tester.pumpWidget(host(cue, SudokuScreen(puzzle: puzzle)));
      for (final cell in sudoku.Cell.all) {
        if (puzzle.givens.valueAt(cell) != null) continue;
        await tester.tap(find.byKey(ValueKey<String>('cell-${cell.index}')));
        await tester.pump();
        await tester.tap(
          find.byKey(ValueKey<String>('digit-${puzzle.solution.valueAt(cell)}')),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('Solved'), findsOneWidget);

      final thrown = whatWasThrown(cue);
      expect(thrown.particles, greaterThan(0));
      expect(thrown.fromBelow, isTrue, reason: 'the whole screen, not a corner');
    });
  });

  group('Block Blast', () {
    final BlockShape single = BlockShape.fromRows(<String>['#']);
    final BlockShape bar3 = BlockShape.fromRows(<String>['#', '#', '#']);
    final BlockShape square = BlockShape.fromRows(<String>['##', '##']);

    /// The bottom [rows] rows one cell short, with a stray block up top so a
    /// clear does not empty the board.
    BlockBoard nearlyFull(int rows) => BlockBoard.fromRows(<String>[
          for (var row = 0; row < boardSize; row++)
            if (row == 0)
              '1.......'
            else if (row >= boardSize - rows)
              '1111111.'
            else
              '........',
        ]);

    Future<void> drop(
      WidgetTester tester,
      int index,
      BlockShape shape,
      Coord anchor,
    ) async {
      final board = tester.getRect(find.byType(BlockBoardView));
      final cell = board.width / boardSize;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(ValueKey<String>('hand-slot-$index'))),
      );
      await tester.pump();
      await gesture.moveTo(
        board.topLeft +
            Offset(
              anchor.col * cell + shape.width * cell / 2,
              anchor.row * cell + shape.height * cell + kCarryLift * cell,
            ),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('an ordinary placement throws nothing', (tester) async {
      final cue = CelebrationCue();
      await tester.pumpWidget(
        host(
          cue,
          BlockBlastScreen(
            initial: gameWith(
              board: BlockBoard.empty(),
              hand: <BlockPiece?>[BlockPiece(square, 1), null, null],
            ),
          ),
        ),
      );
      await drop(tester, 0, square, const Coord(3, 3));
      expect(whatWasThrown(cue).particles, 0);
    });

    testWidgets('three lines at once throws colour from the board', (
      tester,
    ) async {
      final cue = CelebrationCue();
      await tester.pumpWidget(
        host(
          cue,
          BlockBlastScreen(
            initial: gameWith(
              board: nearlyFull(3),
              hand: <BlockPiece?>[BlockPiece(bar3, 1), null, null],
            ),
          ),
        ),
      );
      await drop(tester, 0, bar3, Coord(boardSize - 3, boardSize - 1));

      final thrown = whatWasThrown(cue);
      expect(thrown.particles, greaterThan(0));
      expect(
        thrown.fromBelow,
        isFalse,
        reason: 'it happened on the board, so it should come from there',
      );
    });

    testWidgets('a new best throws colour across the screen', (tester) async {
      final cue = CelebrationCue();
      final scores = BestScores(MemoryStore());
      await scores.record('blockblast', 10);
      await tester.pumpWidget(
        host(
          cue,
          BlockBlastScreen(
            initial: gameWith(
              board: BlockBoard.fromRows(<String>[
                '1111111.',
                '11111111',
                '11111111',
                '11111111',
                '11111111',
                '11111111',
                '11111111',
                '11111111',
              ]),
              hand: <BlockPiece?>[BlockPiece(square, 1), null, null],
              score: 900,
            ),
            scores: scores,
            best: 10,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A new best.'), findsOneWidget);

      final thrown = whatWasThrown(cue);
      expect(thrown.particles, greaterThan(0));
      expect(thrown.fromBelow, isTrue);
    });

    testWidgets('a run that falls short of the best throws nothing', (
      tester,
    ) async {
      final cue = CelebrationCue();
      final scores = BestScores(MemoryStore());
      await scores.record('blockblast', 5000);
      await tester.pumpWidget(
        host(
          cue,
          BlockBlastScreen(
            initial: gameWith(
              board: BlockBoard.fromRows(<String>[
                '1111111.',
                '11111111',
                '11111111',
                '11111111',
                '11111111',
                '11111111',
                '11111111',
                '11111111',
              ]),
              hand: <BlockPiece?>[BlockPiece(square, 1), null, null],
              score: 12,
            ),
            scores: scores,
            best: 5000,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(whatWasThrown(cue).particles, 0);
    });

    testWidgets('passing a milestone sends up fireworks, not confetti', (
      tester,
    ) async {
      final cue = CelebrationCue();
      await tester.pumpWidget(
        host(
          cue,
          BlockBlastScreen(
            initial: gameWith(
              board: BlockBoard.empty(),
              hand: <BlockPiece?>[BlockPiece(square, 1), null, null],
              score: kPointsPerCheer - 2,
            ),
          ),
        ),
      );
      await drop(tester, 0, square, const Coord(3, 3));

      final thrown = whatWasThrown(cue);
      expect(thrown.shells, greaterThan(0), reason: 'shells, not a spray');
      expect(
        thrown.particles,
        0,
        reason: 'nothing is out yet: the shells have to go up first',
      );
    });

    testWidgets('a single line throws nothing', (tester) async {
      final cue = CelebrationCue();
      await tester.pumpWidget(
        host(
          cue,
          BlockBlastScreen(
            initial: gameWith(
              board: nearlyFull(1),
              hand: <BlockPiece?>[BlockPiece(single, 1), null, null],
            ),
          ),
        ),
      );
      await drop(tester, 0, single, Coord(boardSize - 1, boardSize - 1));
      expect(whatWasThrown(cue).particles, 0);
    });
  });

  group('Chess', () {
    // The fool's mate, already played: white to move and mated, so black won.
    const String blackHasMated =
        'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3';

    Widget board(CelebrationCue cue, chess.Opponent opponent) => host(
          cue,
          ChessScreen(
            initial: chess.ChessGame.fromPosition(chess.Position.fromFen(blackHasMated)),
            opponent: opponent,
            chooser: firstLegalMove,
          ),
        );

    testWidgets('winning throws colour across the screen', (tester) async {
      final cue = CelebrationCue();
      await tester.pumpWidget(
        board(
          cue,
          const chess.Opponent.computer(
            level: chess.BotLevel.easy,
            plays: chess.PieceColor.white,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Checkmate'), findsOneWidget);

      final thrown = whatWasThrown(cue);
      expect(thrown.particles, greaterThan(0));
      expect(thrown.fromBelow, isTrue);
    });

    testWidgets('losing to the computer throws nothing', (tester) async {
      final cue = CelebrationCue();
      await tester.pumpWidget(
        board(
          cue,
          const chess.Opponent.computer(
            level: chess.BotLevel.easy,
            plays: chess.PieceColor.black,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Checkmate'), findsOneWidget);
      expect(
        whatWasThrown(cue).particles,
        0,
        reason: 'the computer won, and it does not need cheering',
      );
    });

    testWidgets('two people at one phone: somebody won, so it throws', (
      tester,
    ) async {
      final cue = CelebrationCue();
      await tester.pumpWidget(board(cue, const chess.Opponent.twoPlayers()));
      await tester.pumpAndSettle();
      expect(whatWasThrown(cue).particles, greaterThan(0));
    });
  });
}
