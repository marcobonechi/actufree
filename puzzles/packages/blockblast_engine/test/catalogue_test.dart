import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:test/test.dart';

void main() {
  test('every catalogued shape is distinct', () {
    expect(
      ShapeCatalogue.shapes.toSet(),
      hasLength(ShapeCatalogue.shapes.length),
    );
  });

  test('every shape fits on an empty board', () {
    final board = BlockBoard.empty();
    for (final shape in ShapeCatalogue.shapes) {
      expect(
        board.fitsAnywhere(shape),
        isTrue,
        reason: '$shape does not fit an empty board',
      );
      expect(shape.width, lessThanOrEqualTo(boardSize));
      expect(shape.height, lessThanOrEqualTo(boardSize));
    }
  });

  test('rotating a family produces the orientations it should', () {
    // A square has one orientation, an S two, an L four. If rotation were
    // wrong, these counts are the first thing to go.
    final byShape = <BlockShape, int>{};
    for (final shape in ShapeCatalogue.shapes) {
      byShape[shape] = (byShape[shape] ?? 0) + 1;
    }
    expect(byShape[BlockShape.fromRows(<String>['##', '##'])], 1);
    expect(
      ShapeCatalogue.shapes.where(
        (BlockShape s) => s.size == 4 && s.width == 4 && s.height == 1,
      ),
      hasLength(1),
    );
    expect(
      ShapeCatalogue.shapes.where(
        (BlockShape s) => s.size == 4 && s.width == 1 && s.height == 4,
      ),
      hasLength(1),
    );
  });

  test('the pieces that decide a game are the rare ones', () {
    // The 1x1 goes anywhere, so a common one would let a player dig out of
    // any corner; the 9-cell block needs a third of the board free, so a
    // common one would end runs on the deal. Both stay well below average.
    final average = ShapeCatalogue.totalWeight / ShapeCatalogue.entries.length;
    final single = ShapeCatalogue.entries.singleWhere(
      (CataloguedShape e) => e.shape.size == 1,
    );
    final biggest = ShapeCatalogue.entries.reduce(
      (CataloguedShape a, CataloguedShape b) =>
          b.shape.size > a.shape.size ? b : a,
    );
    expect(biggest.shape.size, 9);
    expect(single.weight, lessThan(average));
    expect(biggest.weight, lessThan(average));
    expect(biggest.weight, lessThanOrEqualTo(single.weight));
  });

  test('the 2x3 block is not a stranger', () {
    // It was 5.4% of draws and players noticed its absence, which is the
    // wrong thing for a shape to be memorable for.
    final rect = ShapeCatalogue.entries.where(
      (CataloguedShape e) => e.shape.size == 6,
    );
    expect(rect, hasLength(2), reason: 'two orientations');
    final share = rect.fold(0, (int sum, CataloguedShape e) => sum + e.weight) /
        ShapeCatalogue.totalWeight;
    expect(share, greaterThan(0.07));
  });

  test('weights cover the whole draw range and nothing beyond it', () {
    final seen = <BlockShape>{};
    for (var draw = 0; draw < ShapeCatalogue.totalWeight; draw++) {
      seen.add(ShapeCatalogue.entryAt(draw).shape);
    }
    expect(seen, hasLength(ShapeCatalogue.shapes.length));
    expect(() => ShapeCatalogue.entryAt(-1), throwsRangeError);
    expect(
      () => ShapeCatalogue.entryAt(ShapeCatalogue.totalWeight),
      throwsRangeError,
    );
  });
}
