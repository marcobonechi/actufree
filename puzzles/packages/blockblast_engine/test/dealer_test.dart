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

  group('the assist', () {
    /// A board with [filled] cells occupied, packed from the top left.
    BlockBoard packed(int filled) {
      final rows = <String>[];
      for (var row = 0; row < boardSize; row++) {
        rows.add(<String>[
          for (var col = 0; col < boardSize; col++)
            row * boardSize + col < filled ? '1' : '.',
        ].join());
      }
      return BlockBoard.fromRows(rows);
    }

    test('an open board gets no help at all', () {
      expect(Dealer.assistChance(BlockBoard.empty()), 0);
      expect(
        Dealer.assistChance(packed((cellCount * Dealer.assistFloor).floor())),
        0,
      );
    });

    test('help arrives as the board fills, and then stops rising', () {
      final chances = <double>[
        for (var filled = 0; filled <= cellCount; filled += 4)
          Dealer.assistChance(packed(filled)),
      ];
      for (var i = 1; i < chances.length; i++) {
        expect(chances[i], greaterThanOrEqualTo(chances[i - 1]));
      }
      expect(chances.last, Dealer.assistCeiling);
      expect(
        Dealer.assistChance(packed(cellCount)),
        Dealer.assistCeiling,
      );
    });

    test('it never promises every piece, even on a hopeless board', () {
      // A hand that always clears would take the ending away, and an ending
      // the player cannot reach is not a game.
      expect(Dealer.assistCeiling, lessThan(1));
    });

    /// What share of an unbiased fitting draw would clear a line on [board].
    ///
    /// The baseline the assist has to beat. Comparing two different boards
    /// would only measure how clearable each one happens to be.
    double unbiasedClearShare(BlockBoard board) {
      var fitting = 0;
      var clearing = 0;
      for (final entry in ShapeCatalogue.entries) {
        if (!board.fitsAnywhere(entry.shape)) continue;
        fitting += entry.weight;
        if (board.canClearWith(entry.shape)) clearing += entry.weight;
      }
      return clearing / fitting;
    }

    test('a board in trouble is dealt more line-clearers than chance', () {
      // Three rows six cells wide: several shapes finish a row, most do not.
      final board = BlockBoard.fromRows(<String>[
        '........',
        '........',
        '........',
        '........',
        '........',
        '111111..',
        '111111..',
        '111111..',
      ]);
      final chance = unbiasedClearShare(board);
      expect(
        chance,
        lessThan(0.8),
        reason: 'a board this clearable could not tell the assist apart',
      );

      const deals = 400;
      var dealt = 0;
      for (var seed = 0; seed < deals; seed++) {
        dealt += Dealer.deal(board, seed)
            .pieces
            .where((BlockPiece p) => board.canClearWith(p.shape))
            .length;
      }
      final share = dealt / (deals * handSize);
      expect(
        share,
        greaterThan(chance + 0.15),
        reason: 'dealt ${share.toStringAsFixed(2)} vs '
            'chance ${chance.toStringAsFixed(2)}',
      );
    });

    test('help is still only help: the pieces stay real catalogue shapes', () {
      final crowded = BlockBoard.fromRows(<String>[
        '........',
        '11111111',
        '11111111',
        '11111111',
        '11111111',
        '11111111',
        '111111..',
        '111111..',
      ]);
      for (var seed = 0; seed < 200; seed++) {
        for (final piece in Dealer.deal(crowded, seed).pieces) {
          expect(ShapeCatalogue.shapes, contains(piece.shape));
          expect(crowded.fitsAnywhere(piece.shape), isTrue);
        }
      }
    });
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
