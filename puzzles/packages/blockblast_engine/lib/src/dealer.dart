import 'dart:math';

import 'board.dart';
import 'catalogue.dart';
import 'constants.dart';
import 'piece.dart';
import 'shape.dart';

/// A hand of pieces, and the seed the next deal should use.
final class Deal {
  /// Records a deal.
  const Deal(this.pieces, this.nextSeed);

  /// The pieces dealt, [handSize] of them.
  final List<BlockPiece> pieces;

  /// The seed for the deal after this one.
  final int nextSeed;
}

/// Where new hands come from.
///
/// Deals are a pure function of the board and a seed: the same pair always
/// produces the same hand, and each deal hands back the seed for the next one.
/// That is what lets a game be saved as a single integer of randomness rather
/// than as the internal state of a [Random], and what makes a bad run
/// reproducible from its opening seed.
abstract final class Dealer {
  /// How many times a hand is redrawn in the hope of finding one that fits
  /// before a piece is replaced outright.
  ///
  /// A few honest attempts keep the usual deal untouched by the fairness rule;
  /// the replacement below is the backstop for a board so full that redrawing
  /// is unlikely to help.
  static const int _redrawAttempts = 8;

  /// Deals [handSize] pieces for [board] from [seed].
  ///
  /// At least one of them fits somewhere. A deal that could not be played at
  /// all would end the game on the deal rather than on anything the player
  /// did, which is the one way of losing nobody learns from.
  ///
  /// Note the guarantee is only about the moment of dealing: playing the piece
  /// that fit can easily leave the other two with nowhere to go, and that is
  /// the game.
  static Deal deal(BlockBoard board, int seed) {
    final random = Random(seed);
    var pieces = _draw(random);
    for (var attempt = 0;
        attempt < _redrawAttempts && !_anyFits(board, pieces);
        attempt++) {
      pieces = _draw(random);
    }
    if (!_anyFits(board, pieces)) {
      pieces = List<BlockPiece>.of(pieces);
      pieces[random.nextInt(handSize)] = BlockPiece(
        _shapeThatFits(board, random),
        1 + random.nextInt(paintCount),
      );
    }
    return Deal(
      List<BlockPiece>.unmodifiable(pieces),
      random.nextInt(1 << 31),
    );
  }

  static List<BlockPiece> _draw(Random random) => <BlockPiece>[
        for (var i = 0; i < handSize; i++)
          BlockPiece(
            ShapeCatalogue.entryAt(random.nextInt(ShapeCatalogue.totalWeight))
                .shape,
            1 + random.nextInt(paintCount),
          ),
      ];

  static bool _anyFits(BlockBoard board, List<BlockPiece> pieces) =>
      pieces.any((BlockPiece piece) => board.fitsAnywhere(piece.shape));

  /// A shape that fits on [board], chosen by weight from those that do.
  ///
  /// There is always one. A completely full board is not reachable — the row
  /// that filled it would have cleared — so some cell is empty, and the 1x1
  /// goes anywhere.
  static BlockShape _shapeThatFits(BlockBoard board, Random random) {
    final usable = <CataloguedShape>[
      for (final entry in ShapeCatalogue.entries)
        if (board.fitsAnywhere(entry.shape)) entry,
    ];
    if (usable.isEmpty) {
      throw StateError('no catalogued shape fits, which should be impossible');
    }
    final total = usable.fold(0, (int sum, CataloguedShape e) => sum + e.weight);
    var draw = random.nextInt(total);
    for (final entry in usable) {
      draw -= entry.weight;
      if (draw < 0) return entry.shape;
    }
    throw StateError('weights do not sum to their own total');
  }
}
