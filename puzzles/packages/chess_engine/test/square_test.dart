import 'package:chess_engine/chess_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Square', () {
    test('names the top left square a8 and the bottom right h1', () {
      expect(Square(0, 0).name, 'a8');
      expect(Square(7, 7).name, 'h1');
      expect(Square.fromIndex(0).name, 'a8');
      expect(Square.fromIndex(squareCount - 1).name, 'h1');
    });

    test('parses algebraic names', () {
      expect(Square.parse('e4'), Square(4, 4));
      expect(Square.parse('a1'), Square(7, 0));
      expect(Square.tryParse('j9'), isNull);
      expect(Square.tryParse('e'), isNull);
      expect(Square.tryParse(''), isNull);
      expect(() => Square.parse('nope'), throwsFormatException);
    });

    test('round trips every square through its name', () {
      for (final square in Square.all) {
        expect(Square.parse(square.name), square);
      }
    });

    test('knows a1 is dark and h1 is light', () {
      expect(Square.parse('a1').isLight, isFalse);
      expect(Square.parse('h1').isLight, isTrue);
      expect(Square.parse('a8').isLight, isTrue);
    });

    test('offsets off the board come back null rather than wrapping', () {
      expect(Square.parse('a1').offset(0, -1), isNull);
      expect(Square.parse('h8').offset(-1, 0), isNull);
      expect(Square.parse('e4').offset(-1, 1), Square.parse('f5'));
    });

    test('rejects coordinates outside the board', () {
      expect(() => Square(8, 0), throwsRangeError);
      expect(() => Square.fromIndex(64), throwsRangeError);
    });

    test('is a value type', () {
      expect(Square(3, 4), Square(3, 4));
      expect(Square(3, 4).hashCode, Square(3, 4).hashCode);
      expect(Square(3, 4), isNot(Square(4, 3)));
    });
  });
}
