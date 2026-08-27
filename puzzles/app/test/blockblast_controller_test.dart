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
