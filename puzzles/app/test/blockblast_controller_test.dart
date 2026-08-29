import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles_app/blockblast/block_game.dart';

/// A game in an arbitrary state, built through the save format.
BlockGame gameWith({
  required BlockBoard board,
  required List<BlockPiece?> hand,
  int score = 0,
}) {
  return BlockGame.fromJson(<String, Object?>{
    'board': board.toJson(),
    'hand': <Object?>[for (final piece in hand) piece?.toJson()],
    'score': score,
    'seed': 1,
  });
}

void main() {
  final single = BlockShape.fromRows(<String>['#']);
  final square = BlockShape.fromRows(<String>['##', '##']);

  test('a fresh controller carries nothing and previews nothing', () {
    final game = BlockBlastGame(BlockGame.newGame(1));
    expect(game.carrying, isNull);
    expect(game.anchor, isNull);
    expect(game.wouldFill, isEmpty);
    expect(game.wouldClear, isEmpty);
    expect(game.score, 0);
  });

  test('dragging over a legal square previews where it would land', () {
    final game = BlockBlastGame(
      gameWith(
        board: BlockBoard.empty(),
        hand: <BlockPiece?>[BlockPiece(square, 1), null, null],
      ),
    )
      ..startDrag(0)
      ..updateDrag(const Coord(2, 3));

    expect(game.carrying, 0);
    expect(game.anchor, const Coord(2, 3));
    expect(game.wouldFill, <Coord>{
      const Coord(2, 3),
      const Coord(2, 4),
      const Coord(3, 3),
      const Coord(3, 4),
    });
    expect(game.wouldClear, isEmpty);
    // Previewing does not place anything.
    expect(game.state.board.isEmpty, isTrue);
  });

  test('dragging where it will not fit previews nothing', () {
    final game = BlockBlastGame(
      gameWith(
        board: BlockBoard.empty(),
        hand: <BlockPiece?>[BlockPiece(square, 1), null, null],
      ),
    )
      ..startDrag(0)
      ..updateDrag(const Coord(2, 3));
    expect(game.wouldFill, isNotEmpty);

    // Off the bottom-right corner, where a 2x2 has no room.
    game.updateDrag(const Coord(boardSize - 1, boardSize - 1));
    expect(game.anchor, isNull);
    expect(game.wouldFill, isEmpty);

    game.updateDrag(null);
    expect(game.wouldFill, isEmpty);
  });

  test('the preview says which lines would go out', () {
    final game = BlockBlastGame(
      gameWith(
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
      ),
    )
      ..startDrag(0)
      ..updateDrag(const Coord(0, boardSize - 1));

    expect(game.wouldClear, hasLength(boardSize));
    expect(game.wouldClear, contains(const Coord(0, 0)));
    // Still only a preview.
    expect(game.state.board.paintAt(const Coord(0, 0)), 1);
  });

  test('dropping on a legal square places, scores and clears', () {
    final game = BlockBlastGame(
      gameWith(
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
      ),
    )
      ..startDrag(0)
      ..updateDrag(const Coord(0, boardSize - 1))
      ..drop();

    expect(game.state.board.isEmpty, isTrue);
    expect(game.score, Scoring.forPlacement(cells: 1, lines: 1));
    expect(game.lastLines, 1);
    expect(game.clearTick, 1);
    expect(game.clearing, hasLength(boardSize));
    expect(game.carrying, isNull);
    expect(game.wouldFill, isEmpty);
  });

  test('dropping with nowhere to land puts the piece back', () {
    final game = BlockBlastGame(
      gameWith(
        board: BlockBoard.empty(),
        hand: <BlockPiece?>[BlockPiece(square, 1), null, null],
      ),
    )
      ..startDrag(0)
      ..updateDrag(null)
      ..drop();

    expect(game.state.board.isEmpty, isTrue);
    expect(game.pieceAt(0), isNotNull);
    expect(game.carrying, isNull);
    expect(game.score, 0);
  });

  test('a clear that repeats itself still ticks', () {
    // Two identical clears in a row produce the same set of cells. Without the
    // tick the board would have no way to tell the second one happened.
    var game = BlockBlastGame(
      gameWith(
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
      ),
    )
      ..startDrag(0)
      ..updateDrag(const Coord(0, boardSize - 1))
      ..drop();
    final first = game.clearing;
    expect(game.clearTick, 1);

    game = BlockBlastGame(
      gameWith(
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
      ),
    )
      ..startDrag(0)
      ..updateDrag(const Coord(0, boardSize - 1))
      ..drop();
    expect(game.clearing, first);
    expect(game.clearTick, 1);
  });

  test('a piece with nowhere left to go is reported as spent', () {
    final game = BlockBlastGame(
      gameWith(
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
        hand: <BlockPiece?>[
          BlockPiece(square, 1),
          BlockPiece(single, 2),
          null,
        ],
      ),
    );
    expect(game.fitsSomewhere(0), isFalse);
    expect(game.fitsSomewhere(1), isTrue);
    expect(game.fitsSomewhere(2), isFalse, reason: 'that slot is empty');
    expect(game.isOver, isFalse);
  });

  test('restarting throws the board away', () {
    final game = BlockBlastGame(BlockGame.newGame(4));
    final anchors = game.state.board.anchorsFor(game.pieceAt(0)!.shape);
    game
      ..startDrag(0)
      ..updateDrag(anchors.first)
      ..drop();
    expect(game.score, greaterThan(0));

    game.restart(9);
    expect(game.score, 0);
    expect(game.state.board.isEmpty, isTrue);
    expect(game.state.remaining, hasLength(handSize));
    expect(game.clearing, isEmpty);
  });

  group('cheers', () {
    BlockShape bar(int height) =>
        BlockShape.fromRows(<String>[for (var i = 0; i < height; i++) '#']);

    /// The bottom [rows] rows one cell short, with a stray block up top.
    ///
    /// The stray matters: without it, clearing the only filled rows empties
    /// the board, and every one of these would be testing the sweep instead
    /// of what it meant to.
    BlockBoard nearlyFull(int rows) => BlockBoard.fromRows(<String>[
          for (var row = 0; row < boardSize; row++)
            if (row == 0)
              '1.......'
            else if (row >= boardSize - rows)
              '1111111.'
            else
              '........',
        ]);

    void play(BlockBlastGame game, int index, Coord anchor) {
      game
        ..startDrag(index)
        ..updateDrag(anchor)
        ..drop();
    }

    test('an ordinary placement is not an occasion', () {
      final game = BlockBlastGame(
        gameWith(
          board: BlockBoard.empty(),
          hand: <BlockPiece?>[BlockPiece(square, 1), null, null],
        ),
      );
      play(game, 0, const Coord(3, 3));
      expect(game.cheer, isNull);
      expect(game.cheerTick, 0);
    });

    test('a single line is not either', () {
      final game = BlockBlastGame(
        gameWith(
          board: nearlyFull(1),
          hand: <BlockPiece?>[BlockPiece(single, 1), null, null],
        ),
      );
      play(game, 0, const Coord(boardSize - 1, boardSize - 1));
      expect(game.lastLines, 1);
      expect(game.cheer, isNull);
      expect(game.cheerTick, 0);
    });

    test('two lines on their own are not, the first time', () {
      final game = BlockBlastGame(
        gameWith(
          board: nearlyFull(2),
          hand: <BlockPiece?>[BlockPiece(bar(2), 1), null, null],
        ),
      );
      play(game, 0, const Coord(boardSize - 2, boardSize - 1));
      expect(game.lastLines, 2);
      expect(game.cheer, isNull);
      expect(game.doublesTowardsCheer, 1);
    });

    test('three lines at once is', () {
      final game = BlockBlastGame(
        gameWith(
          board: nearlyFull(3),
          hand: <BlockPiece?>[BlockPiece(bar(3), 1), null, null],
        ),
      );
      play(game, 0, const Coord(boardSize - 3, boardSize - 1));
      expect(game.lastLines, 3);
      expect(game.state.board.isEmpty, isFalse, reason: 'the stray survives');
      expect(game.cheer, Cheer.bigClear);
      expect(game.cheerTick, 1);
    });

    test('emptying the board outranks whatever cleared it', () {
      // No stray this time, so the three lines take the last of it with them.
      final game = BlockBlastGame(
        gameWith(
          board: BlockBoard.fromRows(<String>[
            for (var row = 0; row < boardSize; row++)
              if (row >= boardSize - 3) '1111111.' else '........',
          ]),
          hand: <BlockPiece?>[BlockPiece(bar(3), 1), null, null],
        ),
      );
      play(game, 0, const Coord(boardSize - 3, boardSize - 1));
      expect(game.state.board.isEmpty, isTrue);
      expect(game.cheer, Cheer.sweep, reason: 'the rarer of the two');
      expect(game.cheerTick, 1, reason: 'one cheer, not two');
    });

    test('every third double is cheered, and the two before it are not', () {
      // Three pairs of rows, each a cell short in a different column, so one
      // hand can make three separate doubles without the board being rebuilt
      // underneath the counter.
      final game = BlockBlastGame(
        gameWith(
          board: BlockBoard.fromRows(<String>[
            '1.......',
            '........',
            '1111111.',
            '1111111.',
            '111111.1',
            '111111.1',
            '11111.11',
            '11111.11',
          ]),
          hand: <BlockPiece?>[
            BlockPiece(bar(2), 1),
            BlockPiece(bar(2), 2),
            BlockPiece(bar(2), 3),
          ],
        ),
      );

      final cheers = <Cheer?>[];
      for (final (index, anchor) in <(int, Coord)>[
        (0, Coord(2, 7)),
        (1, Coord(4, 6)),
        (2, Coord(6, 5)),
      ]) {
        play(game, index, anchor);
        expect(game.lastLines, 2, reason: 'piece $index should take two');
        cheers.add(game.cheer);
      }

      expect(game.doublesTowardsCheer, kDoublesPerCheer);
      expect(cheers, <Cheer?>[null, null, Cheer.doubles]);
      expect(game.cheerTick, 1, reason: 'only the third fires');
    });

    test('crossing a milestone is cheered', () {
      // A placement that takes the score past a multiple of the interval.
      final game = BlockBlastGame(
        gameWith(
          board: BlockBoard.empty(),
          hand: <BlockPiece?>[BlockPiece(square, 1), null, null],
          score: kPointsPerCheer - 2,
        ),
      );
      // Deliberately not reading milestonesPassed first: doing so once hid a
      // bug where the baseline was only worked out on first read, by which
      // time the placement had already moved the score past it.
      play(game, 0, const Coord(3, 3));
      expect(game.score, greaterThanOrEqualTo(kPointsPerCheer));
      expect(game.cheer, Cheer.milestone);
      expect(game.milestonesPassed, 1);
    });

    test('a placement short of the next milestone is not', () {
      final game = BlockBlastGame(
        gameWith(
          board: BlockBoard.empty(),
          hand: <BlockPiece?>[BlockPiece(square, 1), null, null],
          score: kPointsPerCheer - 40,
        ),
      );
      play(game, 0, const Coord(3, 3));
      expect(game.cheer, isNull);
      expect(game.milestonesPassed, 0);
    });

    test('a resumed run does not celebrate the milestones it arrived with', () {
      // Picked up at three milestones in: the next placement owes nothing.
      final game = BlockBlastGame(
        gameWith(
          board: BlockBoard.empty(),
          hand: <BlockPiece?>[BlockPiece(square, 1), null, null],
          score: kPointsPerCheer * 3 + 10,
        ),
      );
      expect(game.milestonesPassed, 3);
      play(game, 0, const Coord(3, 3));
      expect(game.cheer, isNull);
    });

    test('a rarer thing outranks a milestone that lands with it', () {
      // Three lines and a milestone at once: the triple is twenty times the
      // rarer of the two, so that is what the player sees.
      final game = BlockBlastGame(
        gameWith(
          board: nearlyFull(3),
          hand: <BlockPiece?>[BlockPiece(bar(3), 1), null, null],
          score: kPointsPerCheer - 2,
        ),
      );
      play(game, 0, const Coord(boardSize - 3, boardSize - 1));
      expect(game.score, greaterThan(kPointsPerCheer));
      expect(game.cheer, Cheer.bigClear);
      expect(game.milestonesPassed, 1, reason: 'still counted, just not shown');
      expect(game.cheerTick, 1, reason: 'one cheer, not two');
    });

    test('starting again forgets the count', () {
      final game = BlockBlastGame(
        gameWith(
          board: nearlyFull(2),
          hand: <BlockPiece?>[BlockPiece(bar(2), 1), null, null],
        ),
      );
      play(game, 0, const Coord(boardSize - 2, boardSize - 1));
      expect(game.doublesTowardsCheer, 1);
      game.restart(3);
      expect(game.doublesTowardsCheer, 0);
      expect(game.milestonesPassed, 0);
      expect(game.cheer, isNull);
    });
  });

  test('every change notifies, so the screen redraws', () {
    var notifications = 0;
    final game = BlockBlastGame(BlockGame.newGame(6))
      ..addListener(() => notifications++);
    final anchors = game.state.board.anchorsFor(game.pieceAt(0)!.shape);

    game.startDrag(0);
    expect(notifications, 1);
    game.updateDrag(anchors.first);
    expect(notifications, 2);
    // The same square again is not news.
    game.updateDrag(anchors.first);
    expect(notifications, 2);
    game.drop();
    expect(notifications, 3);
  });
}
