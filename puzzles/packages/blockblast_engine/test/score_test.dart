import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:test/test.dart';

void main() {
  test('a placement that clears nothing scores its cells', () {
    expect(Scoring.forPlacement(cells: 4, lines: 0), 4);
    expect(Scoring.forPlacement(cells: 1, lines: 0), 1);
  });

  test('lines are worth more the more of them come out at once', () {
    // The square, not the sum: two lines at once beat two lines one at a time.
    expect(Scoring.forPlacement(cells: 0, lines: 1), 10);
    expect(Scoring.forPlacement(cells: 0, lines: 2), 40);
    expect(Scoring.forPlacement(cells: 0, lines: 3), 90);
    expect(Scoring.forPlacement(cells: 0, lines: 4), 160);
  });

  test('a double clear beats two singles of the same shape', () {
    final together = Scoring.forPlacement(cells: 3, lines: 2);
    final apart = Scoring.forPlacement(cells: 2, lines: 1) +
        Scoring.forPlacement(cells: 1, lines: 1);
    expect(together, greaterThan(apart));
  });
}
