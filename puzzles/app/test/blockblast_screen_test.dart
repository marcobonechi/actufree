import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_kit/puzzle_kit.dart';
import 'package:puzzles_app/blockblast/block_screen.dart';
import 'package:puzzles_app/blockblast/board_view.dart';
import 'package:puzzles_app/blockblast/carried_piece.dart';
import 'package:puzzles_app/blockblast/hand_tray.dart';
import 'package:puzzles_app/blockblast/piece_view.dart';
import 'package:puzzles_app/theme.dart';

import 'blockblast_controller_test.dart' show gameWith;

void main() {
  final single = BlockShape.fromRows(<String>['#']);
  final domino = BlockShape.fromRows(<String>['##']);
  final square = BlockShape.fromRows(<String>['##', '##']);

  Widget host(BlockGame game, {GameStore? store, BestScores? scores}) =>
      MaterialApp(
        theme: actufreeTheme(Brightness.light),
        home: BlockBlastScreen(initial: game, store: store, scores: scores),
      );

  Finder slot(int index) => find.byKey(ValueKey<String>('hand-slot-$index'));

  /// Drags the piece in [index] so its top-left corner lands on [anchor].
  ///
  /// Mirrors what the screen does in reverse: the piece rides above the
  /// finger, so the finger goes where the piece's bottom edge plus the lift
  /// would put it.
  Future<void> dragTo(
    WidgetTester tester,
    int index,
    BlockShape shape,
    Coord? anchor,
  ) async {
    final board = tester.getRect(find.byType(BlockBoardView));
    final cell = board.width / boardSize;
    final gesture = await tester.startGesture(tester.getCenter(slot(index)));
    await tester.pump();

    final target = anchor == null
        // Somewhere well clear of the board: a drag abandoned over the tray.
        ? board.bottomLeft + Offset(cell, cell * 3)
        : board.topLeft +
            Offset(
              anchor.col * cell + shape.width * cell / 2,
              anchor.row * cell + shape.height * cell + kCarryLift * cell,
            );
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('shows the board, the hand and a score of nothing', (
    tester,
  ) async {
    await tester.pumpWidget(host(BlockGame.newGame(2024)));
    expect(find.byType(BlockBoardView), findsOneWidget);
    for (var index = 0; index < handSize; index++) {
      expect(slot(index), findsOneWidget);
    }
    expect(find.byKey(const ValueKey<String>('score')), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('No best yet'), findsOneWidget);
  });

  testWidgets('dragging a piece onto the board places and scores it', (
    tester,
  ) async {
    final game = gameWith(
      board: BlockBoard.empty(),
      hand: <BlockPiece?>[BlockPiece(square, 1), BlockPiece(single, 2), null],
    );
    await tester.pumpWidget(host(game));
    await dragTo(tester, 0, square, const Coord(2, 3));

    expect(find.text('4'), findsOneWidget, reason: 'four cells, no clear');
    // The slot it came from is now empty, and the other is untouched.
    expect(find.descendant(of: slot(0), matching: find.byType(CustomPaint)),
        findsNothing);
    expect(find.descendant(of: slot(1), matching: find.byType(CustomPaint)),
        findsWidgets);
  });

  testWidgets('a drag that ends off the board puts the piece back', (
    tester,
  ) async {
    final game = gameWith(
      board: BlockBoard.empty(),
      hand: <BlockPiece?>[BlockPiece(square, 1), null, null],
    );
    await tester.pumpWidget(host(game));
    await dragTo(tester, 0, square, null);

    expect(find.text('0'), findsOneWidget);
    expect(find.descendant(of: slot(0), matching: find.byType(CustomPaint)),
        findsWidgets);
  });

  testWidgets('completing a row clears it and pays the line bonus', (
    tester,
  ) async {
    final game = gameWith(
      board: BlockBoard.fromRows(<String>[
        '1111111.',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]),
      hand: <BlockPiece?>[BlockPiece(single, 2), null, null],
    );
    await tester.pumpWidget(host(game));
    await dragTo(tester, 0, single, const Coord(0, boardSize - 1));

    expect(
      find.text('${Scoring.forPlacement(cells: 1, lines: 1)}'),
      findsOneWidget,
    );
  });

  testWidgets('running out of moves ends the game and offers another', (
    tester,
  ) async {
    final game = gameWith(
      board: BlockBoard.fromRows(<String>[
        '..111.11',
        '1.111111',
        '11.11111',
        '.11.1111',
        '1111.111',
        '11111.11',
        '111111.1',
        '1111111.',
      ]),
      hand: <BlockPiece?>[BlockPiece(domino, 1), BlockPiece(domino, 2), null],
      score: 100,
    );
    await tester.pumpWidget(host(game));
    expect(find.byKey(const ValueKey<String>('game-over')), findsNothing);

    await dragTo(tester, 0, domino, const Coord(0, 0));

    expect(find.byKey(const ValueKey<String>('game-over')), findsOneWidget);
    expect(find.text('102 points.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('play-again')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('game-over')), findsNothing);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('a game that is already over says so on the way in', (
    tester,
  ) async {
    // A run closed on the losing board, then reopened.
    final game = gameWith(
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
      hand: <BlockPiece?>[BlockPiece(domino, 1), null, null],
      score: 42,
    );
    await tester.pumpWidget(host(game));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('game-over')), findsOneWidget);
    expect(find.text('42 points.'), findsOneWidget);
  });

  testWidgets('the run is saved as it is played and cleared when it ends', (
    tester,
  ) async {
    final store = GameStore(MemoryStore());
    final game = gameWith(
      board: BlockBoard.empty(),
      hand: <BlockPiece?>[BlockPiece(square, 1), BlockPiece(single, 2), null],
    );
    await tester.pumpWidget(host(game, store: store));
    await dragTo(tester, 0, square, const Coord(0, 0));

    final saved = await store.load(
      'blockblast',
      BlockGame.fromJson,
      slot: kBlockSlot,
    );
    expect(saved, isNotNull);
    expect(saved!.score, 4);
    expect(saved.board.paintAt(const Coord(0, 0)), 1);
    expect(saved.hand[0], isNull);
  });

  testWidgets('a finished run leaves no save to resume into', (tester) async {
    final store = GameStore(MemoryStore());
    final scores = BestScores(MemoryStore());
    final game = gameWith(
      board: BlockBoard.fromRows(<String>[
        '..111.11',
        '1.111111',
        '11.11111',
        '.11.1111',
        '1111.111',
        '11111.11',
        '111111.1',
        '1111111.',
      ]),
      hand: <BlockPiece?>[BlockPiece(domino, 1), BlockPiece(domino, 2), null],
      score: 100,
    );
    await tester.pumpWidget(host(game, store: store, scores: scores));
    await dragTo(tester, 0, domino, const Coord(0, 0));

    expect(await store.has('blockblast', slot: kBlockSlot), isFalse);
    expect(await scores.best('blockblast'), 102);
  });

  testWidgets('a better score is recorded and announced', (tester) async {
    final scores = BestScores(MemoryStore());
    await scores.record('blockblast', 50);
    final game = gameWith(
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
      hand: <BlockPiece?>[BlockPiece(domino, 1), null, null],
      score: 500,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: actufreeTheme(Brightness.light),
        home: BlockBlastScreen(initial: game, scores: scores, best: 50),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A new best.'), findsOneWidget);
    expect(await scores.best('blockblast'), 500);
  });

  testWidgets('a worse score leaves the best where it was', (tester) async {
    final scores = BestScores(MemoryStore());
    await scores.record('blockblast', 900);
    final game = gameWith(
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
      hand: <BlockPiece?>[BlockPiece(domino, 1), null, null],
      score: 10,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: actufreeTheme(Brightness.light),
        home: BlockBlastScreen(initial: game, scores: scores, best: 900),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your best is 900.'), findsOneWidget);
    expect(await scores.best('blockblast'), 900);
  });

  testWidgets('restarting asks first, and only then throws the run away', (
    tester,
  ) async {
    final game = gameWith(
      board: BlockBoard.empty(),
      hand: <BlockPiece?>[BlockPiece(square, 1), BlockPiece(single, 2), null],
    );
    await tester.pumpWidget(host(game));
    await dragTo(tester, 0, square, const Coord(0, 0));
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('restart')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget, reason: 'the run should survive');

    await tester.tap(find.byKey(const ValueKey<String>('restart')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start again'));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
  });

  group('layout', () {
    for (final size in <Size>[
      Size(320, 568), // the smallest phone still worth supporting
      Size(402, 874), // a current phone
      Size(874, 402), // the same phone on its side
      Size(834, 1112), // a tablet
    ]) {
      testWidgets('fits ${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(host(BlockGame.newGame(7)));

        expect(find.byType(BlockBoardView), findsOneWidget);
        for (var index = 0; index < handSize; index++) {
          expect(slot(index), findsOneWidget);
        }
        // An overflow is reported as an exception rather than a failure, so
        // the board being on screen is not on its own enough to pass.
        expect(tester.takeException(), isNull);

        final board = tester.getRect(find.byType(BlockBoardView));
        expect(board.width, closeTo(board.height, 0.01), reason: 'not square');
        expect(board.width, greaterThan(80));
      });
    }
  });

  testWidgets('a piece dropped where it will not fit stays in the tray', (
    tester,
  ) async {
    final game = gameWith(
      board: BlockBoard.fromRows(<String>[
        '11111111',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]),
      hand: <BlockPiece?>[BlockPiece(square, 1), null, null],
    );
    await tester.pumpWidget(host(game));
    // Row 0 is full, so a 2x2 anchored there overlaps and cannot land.
    await dragTo(tester, 0, square, const Coord(0, 0));

    expect(find.text('0'), findsOneWidget);
    expect(
      find.descendant(of: slot(0), matching: find.byType(CustomPaint)),
      findsWidgets,
    );
  });

  testWidgets('a piece can be picked up from anywhere in its slot', (
    tester,
  ) async {
    final game = gameWith(
      board: BlockBoard.empty(),
      hand: <BlockPiece?>[BlockPiece(single, 1), null, null],
    );
    await tester.pumpWidget(host(game));

    // A corner of the slot, well clear of the block drawn in the middle of
    // it. A player aiming at a small piece lands here constantly.
    final slotRect = tester.getRect(slot(0));
    final board = tester.getRect(find.byType(BlockBoardView));
    final cell = board.width / boardSize;

    final gesture = await tester.startGesture(
      slotRect.topLeft + const Offset(6, 6),
    );
    await tester.pump();
    await gesture.moveTo(
      board.topLeft + Offset(cell / 2, cell + kCarryLift * cell),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget, reason: 'the piece never lifted');
  });

  group('carrying', () {
    /// Picks up slot 0 and holds it with its top-left [offset] from the board.
    Future<TestGesture> carry(
      WidgetTester tester,
      BlockShape shape,
      Offset offset,
    ) async {
      final board = tester.getRect(find.byType(BlockBoardView));
      final gesture = await tester.startGesture(tester.getCenter(slot(0)));
      await tester.pump();
      await gesture.moveTo(
        board.topLeft +
            offset +
            Offset(
              shape.width *
                  (board.width / boardSize) /
                  2,
              shape.height * (board.width / boardSize) +
                  kCarryLift * (board.width / boardSize),
            ),
      );
      await tester.pump();
      // Long enough for the settle to finish, so the assertion is about where
      // the piece came to rest rather than where it happened to be passing.
      await tester.pump(kSettleDuration + const Duration(milliseconds: 20));
      return gesture;
    }

    testWidgets('the piece settles onto the square it would land on', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          gameWith(
            board: BlockBoard.empty(),
            hand: <BlockPiece?>[BlockPiece(square, 1), null, null],
          ),
        ),
      );
      final board = tester.getRect(find.byType(BlockBoardView));
      final cell = board.width / boardSize;

      // Held a third of a cell off the grid in both directions. Tracking the
      // pointer would leave it there; snapping pulls it onto the square.
      final gesture = await carry(
        tester,
        square,
        Offset(2 * cell + cell / 3, 2 * cell + cell / 3),
      );

      expect(
        tester.getTopLeft(find.byType(PieceView)),
        offsetMoreOrLessEquals(
          board.topLeft + Offset(2 * cell, 2 * cell),
          epsilon: 0.5,
        ),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a piece with nowhere to land stays under the pointer', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          gameWith(
            board: BlockBoard.fromRows(<String>[
              '11111111',
              '11111111',
              '11111111',
              '11111111',
              '........',
              '........',
              '........',
              '........',
            ]),
            hand: <BlockPiece?>[BlockPiece(square, 1), null, null],
          ),
        ),
      );
      final board = tester.getRect(find.byType(BlockBoardView));
      final cell = board.width / boardSize;

      // Over row 2, which is full: nothing to snap to, so no pretending.
      final held = Offset(2 * cell + cell / 3, 2 * cell + cell / 3);
      final gesture = await carry(tester, square, held);

      expect(
        tester.getTopLeft(find.byType(PieceView)),
        offsetMoreOrLessEquals(board.topLeft + held, epsilon: 0.5),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('snapping does not change where the piece is placed', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          gameWith(
            board: BlockBoard.empty(),
            hand: <BlockPiece?>[BlockPiece(square, 1), null, null],
          ),
        ),
      );
      final board = tester.getRect(find.byType(BlockBoardView));
      final cell = board.width / boardSize;
      final gesture = await carry(
        tester,
        square,
        Offset(2 * cell + cell / 3, 2 * cell + cell / 3),
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('4'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('game-over')),
        findsNothing,
      );
    });
  });

  group('colours', () {
    /// The block colours the board is actually dressed in.
    List<Color> shownBy(WidgetTester tester) {
      final themed = tester.widget<AnimatedTheme>(
        find.byKey(const ValueKey<String>('block-colours')),
      );
      return themed.data.extension<BlockPalette>()!.pieces;
    }

    Future<void> open(WidgetTester tester, int score) async {
      await tester.pumpWidget(
        host(
          gameWith(
            board: BlockBoard.empty(),
            hand: <BlockPiece?>[BlockPiece(single, 1), null, null],
            score: score,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a new run wears the first set', (tester) async {
      await open(tester, 0);
      expect(shownBy(tester), BlockColours.all.first.pieces);
    });

    testWidgets('a run past the interval wears the next set', (tester) async {
      await open(tester, kColourInterval);
      expect(shownBy(tester), BlockColours.all[1].pieces);
    });

    testWidgets('a resumed run comes back in the colours it was left in', (
      tester,
    ) async {
      await open(tester, kColourInterval * 2 + 40);
      expect(shownBy(tester), BlockColours.all[2].pieces);
    });

    testWidgets('dressing the board leaves the other games alone', (
      tester,
    ) async {
      await open(tester, 0);
      final themed = tester.widget<AnimatedTheme>(
        find.byKey(const ValueKey<String>('block-colours')),
      );
      // copyWith replaces the whole extension set rather than merging, so
      // this is the assertion standing between Block Blast and quietly
      // stripping Sudoku's palette out of the theme.
      expect(themed.data.extension<SudokuPalette>(), isNotNull);
    });
  });

  testWidgets('a piece is described for a screen reader', (tester) async {
    final game = gameWith(
      board: BlockBoard.empty(),
      hand: <BlockPiece?>[
        BlockPiece(single, 1),
        BlockPiece(BlockShape.fromRows(<String>['#####']), 2),
        BlockPiece(square, 3),
      ],
    );
    await tester.pumpWidget(host(game));
    final handle = tester.ensureSemantics();

    expect(find.bySemanticsLabel('Single block'), findsOneWidget);
    expect(find.bySemanticsLabel('Bar, 5 blocks wide'), findsOneWidget);
    expect(
      find.bySemanticsLabel('4-block piece, 2 wide and 2 tall'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
