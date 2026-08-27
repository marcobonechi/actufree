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

  test('the 1x1 is in the catalogue and is the rarest thing in it', () {
    final single = ShapeCatalogue.entries.singleWhere(
      (CataloguedShape e) => e.shape.size == 1,
    );
    for (final entry in ShapeCatalogue.entries) {
      expect(entry.weight, greaterThanOrEqualTo(single.weight));
    }
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
