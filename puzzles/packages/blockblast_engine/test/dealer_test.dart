import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:test/test.dart';

void main() {
  test('the same board and seed always deal the same hand', () {
    final board = BlockBoard.empty();
    for (var seed = 0; seed < 20; seed++) {
      final first = Dealer.deal(board, seed);
      final second = Dealer.deal(board, seed);
      expect(first.pieces, second.pieces);
      expect(first.nextSeed, second.nextSeed);
    }
  });

  test('different seeds deal different hands', () {
    final board = BlockBoard.empty();
    final hands = <String>{
      for (var seed = 0; seed < 50; seed++)
        Dealer.deal(board, seed).pieces.toString(),
    };
    expect(hands.length, greaterThan(40));
  });

  test('a deal hands back a usable seed for the next one', () {
    final board = BlockBoard.empty();
    var seed = 7;
    final seen = <int>{seed};
    for (var deal = 0; deal < 50; deal++) {
      seed = Dealer.deal(board, seed).nextSeed;
      expect(seed, greaterThanOrEqualTo(0));
      seen.add(seed);
    }
    expect(seen, hasLength(51), reason: 'the seed chain repeated itself');
  });

  test('a hand is always three pieces, painted within the palette', () {
    for (var seed = 0; seed < 100; seed++) {
      final deal = Dealer.deal(BlockBoard.empty(), seed);
      expect(deal.pieces, hasLength(handSize));
      for (final piece in deal.pieces) {
        expect(piece.paint, inInclusiveRange(1, paintCount));
        expect(ShapeCatalogue.shapes, contains(piece.shape));
      }
    }
  });

  test('every dealt piece fits, however little room is left', () {
    // Boards with a single gap of a given size: the deal has to find the
    // shapes small enough to use it, redrawing or substituting as needed.
    for (var gap = 1; gap <= 4; gap++) {
      final board = BlockBoard.fromRows(<String>[
        for (var row = 0; row < boardSize; row++)
          if (row == 0)
            <String>[
              for (var col = 0; col < boardSize; col++)
                col < boardSize - gap ? '1' : '.',
            ].join()
          else
            '11111111',
      ]);
      for (var seed = 0; seed < 200; seed++) {
        final deal = Dealer.deal(board, seed);
        for (final piece in deal.pieces) {
          expect(
            board.fitsAnywhere(piece.shape),
            isTrue,
            reason: 'gap of $gap, seed $seed: ${piece.shape} does not fit',
          );
        }
      }
    }
  });

  test('a board with one empty cell is dealt three 1x1s', () {
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
    for (var seed = 0; seed < 200; seed++) {
      // The only shape that fits one cell is the 1x1, and every piece has to
      // fit, so there is exactly one hand this board can be dealt.
      for (final piece in Dealer.deal(board, seed).pieces) {
        expect(piece.shape.size, 1, reason: 'seed $seed');
      }
    }
  });

  test('an empty board is dealt from the catalogue untouched by fairness', () {
    // Everything fits an empty board, so no redraw or substitution should
    // happen and the mix should stay close to the catalogue's weights.
    var singles = 0;
    const deals = 2000;
    for (var seed = 0; seed < deals; seed++) {
      singles += Dealer.deal(BlockBoard.empty(), seed)
          .pieces
          .where((BlockPiece p) => p.shape.size == 1)
          .length;
    }
    final expected =
        deals * handSize * 1 / ShapeCatalogue.totalWeight;
    expect(singles, closeTo(expected, expected));
  });
}
