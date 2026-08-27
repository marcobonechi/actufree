import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:test/test.dart';

/// A game in an arbitrary state, built through the save format.
///
/// The engine only ever hands out games that follow from a deal, which is the
/// right default — but a test about what happens when a row is one cell short
/// should not have to play its way there.
BlockGame _gameWith({
  required BlockBoard board,
  required List<BlockPiece?> hand,
  int score = 0,
  int seed = 1,
}) {
  return BlockGame.fromJson(<String, Object?>{
    'board': board.toJson(),
    'hand': <Object?>[for (final piece in hand) piece?.toJson()],
    'score': score,
    'seed': seed,
  });
}

/// The first anchor where the piece in [index] can go, or `null`.
Coord? _anywhereFor(BlockGame game, int index) {
  final piece = game.hand[index];
  if (piece == null) return null;
  final anchors = game.board.anchorsFor(piece.shape);
  return anchors.isEmpty ? null : anchors.first;
}

/// Makes one move, always taking the first piece that fits at the first place
/// it fits — a bad strategy, which is exactly what makes it useful for asking
/// whether a game always ends.
BlockGame _playOne(BlockGame game) {
  for (var index = 0; index < handSize; index++) {
    final anchor = _anywhereFor(game, index);
    if (anchor == null) continue;
    final result = game.place(index, anchor);
    expect(result, isA<PlacementAccepted>());
    return (result as PlacementAccepted).game;
  }
  fail('the game is not over, but nothing could be played');
}

void main() {
  final single = BlockShape.fromRows(<String>['#']);
  final domino = BlockShape.fromRows(<String>['##']);

  test('a new game starts empty, with a full hand and no score', () {
    final game = BlockGame.newGame(1);
    expect(game.board.isEmpty, isTrue);
    expect(game.hand, hasLength(handSize));
    expect(game.remaining, hasLength(handSize));
    expect(game.score, 0);
    expect(game.isOver, isFalse);
  });

  test('the same seed starts the same game', () {
    expect(BlockGame.newGame(42).hand, BlockGame.newGame(42).hand);
    expect(BlockGame.newGame(42).seed, BlockGame.newGame(42).seed);
  });

  test('placing fills the board and empties the slot', () {
    final game = BlockGame.newGame(3);
    final piece = game.hand[0]!;
    final result = game.place(0, const Coord(0, 0)) as PlacementAccepted;

    expect(result.game.hand[0], isNull);
    expect(result.game.hand[1], game.hand[1]);
    expect(result.game.hand[2], game.hand[2]);
    expect(result.filled, piece.shape.at(const Coord(0, 0)).toSet());
    for (final cell in result.filled) {
      expect(result.game.board.paintAt(cell), piece.paint);
    }
    expect(result.points, piece.shape.size);
    expect(result.game.score, piece.shape.size);
    expect(result.dealt, isFalse);
    expect(result.clear.isEmpty, isTrue);
  });

  test('placing leaves the game it came from alone', () {
    final game = BlockGame.newGame(3);
    game.place(0, const Coord(0, 0));
    expect(game.board.isEmpty, isTrue);
    expect(game.hand[0], isNotNull);
    expect(game.score, 0);
  });

  test('an empty slot and an index off the end are both refused', () {
    final game = BlockGame.newGame(5);
    final played = (game.place(0, const Coord(0, 0)) as PlacementAccepted).game;
    for (final index in <int>[0, -1, handSize]) {
      final result = played.place(index, const Coord(4, 4));
      expect(result, isA<PlacementRejected>());
      expect(
        (result as PlacementRejected).reason,
        PlacementRejection.noPieceThere,
      );
    }
  });

  test('a placement that does not fit is refused and changes nothing', () {
    final game = _gameWith(
      board: BlockBoard.empty(),
      hand: <BlockPiece?>[BlockPiece(domino, 1), null, null],
    );
    final result = game.place(0, const Coord(0, boardSize - 1));
    expect(result, isA<PlacementRejected>());
    expect((result as PlacementRejected).reason, PlacementRejection.doesNotFit);
    expect(game.board.isEmpty, isTrue);
  });

  test('canPlace agrees with what place would do', () {
    final game = BlockGame.newGame(13);
    for (var index = 0; index < handSize; index++) {
      for (final anchor in Coord.all) {
        expect(
          game.canPlace(index, anchor),
          game.place(index, anchor) is PlacementAccepted,
          reason: 'piece $index at $anchor',
        );
      }
    }
  });

  test('a new hand arrives only once all three have been played', () {
    var game = BlockGame.newGame(17);
    for (var index = 0; index < handSize; index++) {
      final anchor = _anywhereFor(game, index);
      final result = game.place(index, anchor!) as PlacementAccepted;
      expect(result.dealt, index == handSize - 1);
      game = result.game;
    }
    expect(game.remaining, hasLength(handSize));
    expect(game.seed, isNot(BlockGame.newGame(17).seed));
  });

  test('completing a row clears it and scores it', () {
    final game = _gameWith(
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
    final result =
        game.place(0, const Coord(0, boardSize - 1)) as PlacementAccepted;

    expect(result.clear.rows, <int>[0]);
    expect(result.clear.cols, isEmpty);
    expect(result.game.board.isEmpty, isTrue);
    expect(result.points, Scoring.forPlacement(cells: 1, lines: 1));
    expect(result.game.score, result.points);
    expect(result.filled, <Coord>{const Coord(0, boardSize - 1)});
    expect(result.dealt, isTrue, reason: 'that was the last piece in hand');
  });

  test('a cell can be filled and cleared by the same placement', () {
    final game = _gameWith(
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
    final result =
        game.place(0, const Coord(0, boardSize - 1)) as PlacementAccepted;
    // Where it landed and what went out overlap. Drawing needs both: the piece
    // should be seen arriving before the line it completed goes.
    expect(result.filled, isNotEmpty);
    expect(result.clear.cells, containsAll(result.filled));
  });

  test('a crossing row and column score as a double', () {
    final game = _gameWith(
      board: BlockBoard.fromRows(<String>[
        '.1111111',
        '.1......',
        '.1......',
        '.1......',
        '.1......',
        '.1......',
        '.1......',
        '.1......',
      ]),
      hand: <BlockPiece?>[BlockPiece(single, 3), null, null],
    );
    final result = game.place(0, const Coord(0, 0)) as PlacementAccepted;
    expect(result.clear.rows, <int>[0]);
    expect(result.clear.cols, <int>[1]);
    expect(result.points, Scoring.forPlacement(cells: 1, lines: 2));
    expect(result.game.board.isEmpty, isTrue);
  });

  test('a game with nothing playable left is over', () {
    final board = BlockBoard.fromRows(<String>[
      '1111111.',
      '11111111',
      '11111111',
      '11111111',
      '11111111',
      '11111111',
      '11111111',
      '11111111',
    ]);
    expect(
      _gameWith(
        board: board,
        hand: <BlockPiece?>[BlockPiece(domino, 1), null, null],
      ).isOver,
      isTrue,
    );
    // The same board with a 1x1 still has a move in it.
    expect(
      _gameWith(
        board: board,
        hand: <BlockPiece?>[BlockPiece(domino, 1), BlockPiece(single, 1), null],
      ).isOver,
      isFalse,
    );
  });

  test('a placement can be the one that ends the game', () {
    // Empties scattered so that no line is close to full and only one pair of
    // them sits side by side. Taking that pair leaves nothing but singles.
    final game = _gameWith(
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
    );
    expect(game.isOver, isFalse);

    final result = game.place(0, const Coord(0, 0)) as PlacementAccepted;
    expect(result.clear.isEmpty, isTrue, reason: 'nothing should have cleared');
    expect(result.dealt, isFalse, reason: 'a piece is still in hand');
    // Every gap left is a lone cell, and a domino needs two side by side.
    expect(result.isOver, isTrue);
    expect(result.game.isOver, isTrue);
  });

  test('a game played badly always ends, and the score only goes up', () {
    for (var seed = 0; seed < 30; seed++) {
      var game = BlockGame.newGame(seed);
      var score = 0;
      var moves = 0;
      while (!game.isOver) {
        game = _playOne(game);
        expect(game.score, greaterThanOrEqualTo(score));
        score = game.score;
        expect(++moves, lessThan(2000), reason: 'seed $seed never ended');
      }
      expect(game.score, greaterThan(0));
    }
  });

  test('the board only ever holds paint from pieces that were played', () {
    var game = BlockGame.newGame(99);
    while (!game.isOver) {
      game = _playOne(game);
      for (final coord in Coord.all) {
        expect(game.board.paintAt(coord), inInclusiveRange(0, paintCount));
      }
    }
  });
}
