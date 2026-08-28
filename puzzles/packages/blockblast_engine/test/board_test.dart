import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:test/test.dart';

void main() {
  final single = BlockShape.fromRows(<String>['#']);
  final domino = BlockShape.fromRows(<String>['##']);
  final square = BlockShape.fromRows(<String>['##', '##']);

  test('an empty board holds nothing', () {
    final board = BlockBoard.empty();
    expect(board.isEmpty, isTrue);
    expect(board.filledCount, 0);
    for (final coord in Coord.all) {
      expect(board.isFilled(coord), isFalse);
      expect(board.paintAt(coord), 0);
    }
  });

  test('a placed shape keeps its paint', () {
    final board = BlockBoard.empty().withShape(square, const Coord(2, 3), 4);
    expect(board.filledCount, 4);
    expect(board.paintAt(const Coord(2, 3)), 4);
    expect(board.paintAt(const Coord(3, 4)), 4);
    expect(board.paintAt(const Coord(2, 5)), 0);
  });

  test('placing does not change the board it came from', () {
    final before = BlockBoard.empty();
    before.withShape(square, const Coord(0, 0), 1);
    expect(before.isEmpty, isTrue);
  });

  test('a shape does not fit off the edge', () {
    final board = BlockBoard.empty();
    expect(board.fits(domino, const Coord(0, boardSize - 2)), isTrue);
    expect(board.fits(domino, const Coord(0, boardSize - 1)), isFalse);
    expect(board.fits(domino, const Coord(boardSize, 0)), isFalse);
    expect(board.fits(domino, const Coord(-1, 0)), isFalse);
  });

  test('a shape does not fit over an occupied cell', () {
    final board = BlockBoard.empty().withShape(domino, const Coord(0, 0), 1);
    expect(board.fits(domino, const Coord(0, 0)), isFalse);
    expect(board.fits(domino, const Coord(0, 1)), isFalse);
    expect(board.fits(domino, const Coord(0, 2)), isTrue);
  });

  test('placing where it does not fit throws rather than doing nothing', () {
    final board = BlockBoard.empty().withShape(domino, const Coord(0, 0), 1);
    expect(
      () => board.withShape(domino, const Coord(0, 0), 2),
      throwsArgumentError,
    );
  });

  test('anchors are every legal spot, in row-major order', () {
    final board = BlockBoard.empty();
    final anchors = board.anchorsFor(square);
    expect(anchors, hasLength((boardSize - 1) * (boardSize - 1)));
    expect(anchors.first, const Coord(0, 0));
    expect(anchors.last, const Coord(boardSize - 2, boardSize - 2));
    for (final anchor in anchors) {
      expect(board.fits(square, anchor), isTrue);
    }
  });

  test('fitsAnywhere agrees with anchorsFor', () {
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
    for (final shape in ShapeCatalogue.shapes) {
      expect(board.fitsAnywhere(shape), board.anchorsFor(shape).isNotEmpty);
    }
    expect(board.fitsAnywhere(BlockShape.fromRows(<String>['#'])), isTrue);
    expect(board.fitsAnywhere(domino), isFalse);
  });

  test('a full row clears', () {
    final board = BlockBoard.fromRows(<String>[
      '11111111',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
    ]);
    final clear = board.clearFullLines();
    expect(clear.rows, <int>[0]);
    expect(clear.cols, isEmpty);
    expect(clear.lineCount, 1);
    expect(clear.cells, hasLength(boardSize));
    expect(clear.board.isEmpty, isTrue);
  });

  test('a full column clears', () {
    final board = BlockBoard.fromRows(<String>[
      '2.......',
      '2.......',
      '2.......',
      '2.......',
      '2.......',
      '2.......',
      '2.......',
      '2.......',
    ]);
    final clear = board.clearFullLines();
    expect(clear.rows, isEmpty);
    expect(clear.cols, <int>[0]);
    expect(clear.board.isEmpty, isTrue);
  });

  test('a crossing row and column both clear, sharing their cell', () {
    final board = BlockBoard.fromRows(<String>[
      '11111111',
      '1.......',
      '1.......',
      '1.......',
      '1.......',
      '1.......',
      '1.......',
      '1.......',
    ]);
    final clear = board.clearFullLines();
    expect(clear.rows, <int>[0]);
    expect(clear.cols, <int>[0]);
    expect(clear.lineCount, 2);
    // Fifteen, not sixteen: r1c1 belongs to both lines.
    expect(clear.cells, hasLength(boardSize * 2 - 1));
    expect(clear.board.isEmpty, isTrue);
  });

  test('cells outside the cleared lines are left alone', () {
    final board = BlockBoard.fromRows(<String>[
      '11111111',
      '3.......',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
    ]);
    final clear = board.clearFullLines();
    expect(clear.board.paintAt(const Coord(1, 0)), 3);
    expect(clear.board.filledCount, 1);
  });

  test('nothing full means nothing changes', () {
    final board = BlockBoard.empty().withShape(square, const Coord(0, 0), 1);
    final clear = board.clearFullLines();
    expect(clear.isEmpty, isTrue);
    expect(clear.lineCount, 0);
    expect(clear.board, board);
  });

  group('bestClearFor', () {
    test('an empty board offers nothing to clear', () {
      final board = BlockBoard.empty();
      for (final shape in ShapeCatalogue.shapes) {
        expect(board.bestClearFor(shape), 0, reason: '$shape');
        expect(board.canClearWith(shape), isFalse);
      }
    });

    test('a row one cell short is clearable by a 1x1 and nothing bigger', () {
      final board = BlockBoard.fromRows(<String>[
        '1111111.',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      expect(board.bestClearFor(single), 1);
      // The domino reaches the gap but hangs off the end of the row, so it
      // fits nowhere that completes it.
      expect(board.bestClearFor(domino), 0);
      expect(board.canClearWith(single), isTrue);
      expect(board.canClearWith(domino), isFalse);
    });

    test('a row two cells short needs the piece that spans both', () {
      final board = BlockBoard.fromRows(<String>[
        '111111..',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      expect(board.bestClearFor(domino), 1);
      // A single fills one of the two and completes nothing.
      expect(board.bestClearFor(single), 0);
    });

    test('it counts a crossing row and column as two', () {
      final board = BlockBoard.fromRows(<String>[
        '.1111111',
        '.1......',
        '.1......',
        '.1......',
        '.1......',
        '.1......',
        '.1......',
        '.1......',
      ]);
      expect(board.bestClearFor(single), 2);
    });

    test('it reports the best placement, not the first', () {
      // The 1x1 clears nothing at most squares and two lines at r1c1, and the
      // answer has to be the two.
      final board = BlockBoard.fromRows(<String>[
        '.1111111',
        '.1......',
        '.1......',
        '.1......',
        '.1......',
        '.1......',
        '.1......',
        '.1......',
      ]);
      expect(board.bestClearFor(single), 2);
      expect(board.anchorsFor(single).length, greaterThan(1));
    });

    test('it agrees with actually placing the piece', () {
      // The cheap arithmetic has to match what clearFullLines really does.
      for (var seed = 0; seed < 40; seed++) {
        var game = BlockGame.newGame(seed);
        while (!game.isOver) {
          for (final piece in game.remaining) {
            var actual = 0;
            for (final anchor in game.board.anchorsFor(piece.shape)) {
              final lines = game.board
                  .withShape(piece.shape, anchor, piece.paint)
                  .clearFullLines()
                  .lineCount;
              if (lines > actual) actual = lines;
            }
            expect(
              game.board.bestClearFor(piece.shape),
              actual,
              reason: 'seed $seed, ${piece.shape}',
            );
          }
          final piece = game.remaining.first;
          final index = game.hand.indexOf(piece);
          final anchors = game.board.anchorsFor(piece.shape);
          if (anchors.isEmpty) {
            final other = game.hand.indexWhere(
              (BlockPiece? p) =>
                  p != null && game.board.fitsAnywhere(p.shape),
            );
            game = (game.place(other, game.board.anchorsFor(
              game.hand[other]!.shape,
            ).first) as PlacementAccepted).game;
          } else {
            game = (game.place(index, anchors.first) as PlacementAccepted).game;
          }
        }
      }
    });
  });

  test('a board round-trips through JSON', () {
    final board = BlockBoard.empty()
        .withShape(square, const Coord(1, 1), 3)
        .withShape(domino, const Coord(5, 5), 6);
    expect(BlockBoard.fromJson(board.toJson()), board);
  });

  test('malformed board JSON is refused', () {
    expect(() => BlockBoard.fromJson(<Object?>[1, 2]), throwsFormatException);
    expect(
      () => BlockBoard.fromJson(List<Object?>.filled(cellCount, 'x')),
      throwsFormatException,
    );
  });

  test('boards of the same cells are equal and hash alike', () {
    final one = BlockBoard.empty().withShape(square, const Coord(0, 0), 1);
    final two = BlockBoard.empty().withShape(square, const Coord(0, 0), 1);
    expect(one, two);
    expect(<BlockBoard>{one, two}, hasLength(1));
    expect(
      one,
      isNot(BlockBoard.empty().withShape(square, const Coord(0, 0), 2)),
    );
  });
}
