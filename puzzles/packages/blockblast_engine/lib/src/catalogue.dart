import 'coord.dart';
import 'shape.dart';

/// A shape and how often it is dealt.
final class CataloguedShape {
  /// Catalogues [shape] with the given [weight].
  const CataloguedShape(this.shape, this.weight);

  /// The shape.
  final BlockShape shape;

  /// How often it comes up, relative to the other entries.
  ///
  /// Not a probability: a deal picks from the running total, so an entry of
  /// weight 4 is dealt twice as often as one of weight 2 whatever else is in
  /// the list.
  final int weight;
}

/// Every shape that can be dealt.
///
/// Weights lean towards the small and awkward middle of the range. The 1x1 is
/// deliberately rare — it fits anywhere, so a common one would let a player
/// dig out of any corner and the board would never close in.
abstract final class ShapeCatalogue {
  /// Every dealable shape, each with its weight.
  static final List<CataloguedShape> entries = List<CataloguedShape>.unmodifiable(
    <CataloguedShape>[
      for (final family in _families)
        for (final shape in _rotationsOf(family.shape))
          CataloguedShape(shape, family.weight),
    ],
  );

  /// Every dealable shape, without the weights.
  static final List<BlockShape> shapes = List<BlockShape>.unmodifiable(
    entries.map((CataloguedShape entry) => entry.shape),
  );

  /// The sum of every weight, which is the range a deal draws from.
  static final int totalWeight =
      entries.fold(0, (int sum, CataloguedShape e) => sum + e.weight);

  /// The entry whose weight band contains [draw], a number in
  /// `0..totalWeight - 1`.
  static CataloguedShape entryAt(int draw) {
    RangeError.checkValueInInterval(draw, 0, totalWeight - 1, 'draw');
    var remaining = draw;
    for (final entry in entries) {
      remaining -= entry.weight;
      if (remaining < 0) return entry;
    }
    throw StateError('weights do not sum to totalWeight');
  }
}

/// One shape and its weight, before rotations are worked out.
///
/// Only the distinct orientations of a family are dealable, and each is dealt
/// as often as any other in the family: a square has one, an S has two, an L
/// has four.
final class _Family {
  const _Family(this.shape, this.weight);

  final BlockShape shape;
  final int weight;
}

/// The distinct orientations of [shape], turning clockwise.
///
/// Derived rather than spelled out. Eight hand-written L and J orientations is
/// eight chances to put a cell in the wrong place, and a typo there would show
/// up as a piece that occasionally cannot be placed anywhere sensible rather
/// than as a failing test.
List<BlockShape> _rotationsOf(BlockShape shape) {
  final found = <BlockShape>[];
  var current = shape;
  for (var turn = 0; turn < 4; turn++) {
    if (!found.contains(current)) found.add(current);
    current = _rotate(current);
  }
  return found;
}

/// [shape] turned a quarter turn clockwise.
///
/// `(row, col)` becomes `(col, -row)`; the negative column is pulled back to
/// zero when [BlockShape] normalises.
BlockShape _rotate(BlockShape shape) => BlockShape(
      shape.cells.map((Coord cell) => Coord(cell.col, -cell.row)),
    );

final List<_Family> _families = <_Family>[
  // The rescue piece. Rare on purpose — see the class doc.
  _Family(BlockShape.fromRows(<String>['#']), 1),

  // Bars. Long ones are rare: a 1x5 needs five in a row, and a hand of three
  // of them is a very short game.
  _Family(BlockShape.fromRows(<String>['##']), 4),
  _Family(BlockShape.fromRows(<String>['###']), 4),
  _Family(BlockShape.fromRows(<String>['####']), 3),
  _Family(BlockShape.fromRows(<String>['#####']), 2),

  // Blocks.
  _Family(BlockShape.fromRows(<String>['##', '##']), 5),
  _Family(BlockShape.fromRows(<String>['###', '###']), 3),
  _Family(BlockShape.fromRows(<String>['###', '###', '###']), 2),

  // Corners.
  _Family(BlockShape.fromRows(<String>['#.', '##']), 4),
  _Family(BlockShape.fromRows(<String>['#..', '#..', '###']), 2),

  // Tetrominoes.
  _Family(BlockShape.fromRows(<String>['#.', '#.', '##']), 3),
  _Family(BlockShape.fromRows(<String>['.#', '.#', '##']), 3),
  _Family(BlockShape.fromRows(<String>['###', '.#.']), 3),
  _Family(BlockShape.fromRows(<String>['.##', '##.']), 3),
  _Family(BlockShape.fromRows(<String>['##.', '.##']), 3),
];
