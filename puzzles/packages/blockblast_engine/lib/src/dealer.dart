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
  /// How many times a piece is redrawn in the hope of finding one that fits
  /// before it is replaced outright.
  ///
  /// A few honest attempts keep the usual deal untouched by the fairness rule;
  /// the replacement below is the backstop for a board so full that redrawing
  /// is unlikely to help.
  static const int _redrawAttempts = 8;

  /// Deals [handSize] pieces for [board] from [seed].
  ///
  /// Every one of them fits somewhere. Being handed a shape that was never
  /// playable costs the player a third of the hand for reasons they had no
  /// part in, which is not a thing anyone can learn to play around.
  ///
  /// The guarantee covers the moment of dealing and nothing past it. Where the
  /// first piece goes decides whether the second still has room, and often it
  /// does not — that is the game, and no rule here should try to prevent it.
  /// Measured over a few thousand runs, most games end with a piece still in
  /// hand that fitted perfectly well when it was dealt.
  static Deal deal(BlockBoard board, int seed) {
    final random = Random(seed);
    final pieces = <BlockPiece>[
      for (var i = 0; i < handSize; i++) _drawThatFits(board, random),
    ];
    return Deal(
      List<BlockPiece>.unmodifiable(pieces),
      random.nextInt(1 << 31),
    );
  }

  /// One piece that fits on [board].
  ///
  /// Drawn honestly first, so on an open board — which is most of them — the
  /// catalogue's weights decide the piece and this costs one fit check. Only a
  /// board with little room left falls through to being handed something that
  /// works.
  static BlockPiece _drawThatFits(BlockBoard board, Random random) {
    for (var attempt = 0; attempt < _redrawAttempts; attempt++) {
      final shape = ShapeCatalogue.entryAt(
        random.nextInt(ShapeCatalogue.totalWeight),
      ).shape;
      if (board.fitsAnywhere(shape)) {
        return BlockPiece(shape, 1 + random.nextInt(paintCount));
      }
    }
    return BlockPiece(
      _shapeThatFits(board, random),
      1 + random.nextInt(paintCount),
    );
  }

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
