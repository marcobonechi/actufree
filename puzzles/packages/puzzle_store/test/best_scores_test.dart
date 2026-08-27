import 'package:puzzle_store/puzzle_store.dart';
import 'package:test/test.dart';

void main() {
  test('a game with no history has no score to beat', () async {
    expect(await BestScores(MemoryStore()).best('blockblast'), 0);
  });

  test('a better score is recorded and reported as better', () async {
    final scores = BestScores(MemoryStore());
    expect(await scores.record('blockblast', 120), isTrue);
    expect(await scores.best('blockblast'), 120);
    expect(await scores.record('blockblast', 300), isTrue);
    expect(await scores.best('blockblast'), 300);
  });

  test('a worse or equal score changes nothing', () async {
    final scores = BestScores(MemoryStore());
    await scores.record('blockblast', 300);
    expect(await scores.record('blockblast', 299), isFalse);
    expect(await scores.record('blockblast', 300), isFalse);
    expect(await scores.best('blockblast'), 300);
  });

  test('each game keeps its own best', () async {
    final scores = BestScores(MemoryStore());
    await scores.record('blockblast', 300);
    await scores.record('sudoku', 10);
    expect(await scores.best('blockblast'), 300);
    expect(await scores.best('sudoku'), 10);
  });

  test('an unreadable score counts as none', () async {
    final store = MemoryStore();
    await store.write(BestScores.keyFor('blockblast'), 'quite a lot');
    expect(await BestScores(store).best('blockblast'), 0);
    // And is replaced by the next real score rather than blocking it.
    expect(await BestScores(store).record('blockblast', 5), isTrue);
    expect(await BestScores(store).best('blockblast'), 5);
  });

  test('a best can be forgotten', () async {
    final scores = BestScores(MemoryStore());
    await scores.record('blockblast', 300);
    await scores.clear('blockblast');
    expect(await scores.best('blockblast'), 0);
  });
}
