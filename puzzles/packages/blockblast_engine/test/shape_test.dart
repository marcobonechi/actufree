import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:test/test.dart';

void main() {
  test('cells are normalised to the top-left corner', () {
    final shifted = BlockShape(<Coord>[
      const Coord(4, 7),
      const Coord(5, 7),
      const Coord(5, 8),
    ]);
    expect(shifted.cells, <Coord>[
      const Coord(0, 0),
      const Coord(1, 0),
      const Coord(1, 1),
    ]);
    expect(shifted.width, 2);
    expect(shifted.height, 2);
    expect(shifted.size, 3);
  });

  test('a shape drawn anywhere equals the same shape drawn at the origin', () {
    expect(
      BlockShape(<Coord>[const Coord(9, 9), const Coord(9, 10)]),
      BlockShape.fromRows(<String>['##']),
    );
  });

  test('shapes of the same cells hash alike', () {
    final rows = BlockShape.fromRows(<String>['.##', '##.']);
    final cells = BlockShape(<Coord>[
      const Coord(0, 1),
      const Coord(0, 2),
      const Coord(1, 0),
      const Coord(1, 1),
    ]);
    expect(<BlockShape>{rows, cells}, hasLength(1));
  });

  test('different shapes are not equal', () {
    expect(
      BlockShape.fromRows(<String>['.##', '##.']),
      isNot(BlockShape.fromRows(<String>['##.', '.##'])),
    );
  });

  test('an empty or repeating shape is refused', () {
    expect(() => BlockShape(const <Coord>[]), throwsArgumentError);
    expect(
      () => BlockShape(<Coord>[const Coord(0, 0), const Coord(0, 0)]),
      throwsArgumentError,
    );
  });

  test('at() offsets every cell by the anchor', () {
    final corner = BlockShape.fromRows(<String>['#.', '##']);
    expect(corner.at(const Coord(3, 5)), <Coord>[
      const Coord(3, 5),
      const Coord(4, 5),
      const Coord(4, 6),
    ]);
  });

  test('a shape round-trips through JSON', () {
    for (final shape in ShapeCatalogue.shapes) {
      expect(BlockShape.fromJson(shape.toJson()), shape);
    }
  });

  test('malformed JSON is refused', () {
    expect(() => BlockShape.fromJson(<Object?>[0]), throwsFormatException);
    expect(
      () => BlockShape.fromJson(<Object?>['0', '0']),
      throwsFormatException,
    );
  });
}
