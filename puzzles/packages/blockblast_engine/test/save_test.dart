import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:puzzle_store/puzzle_store.dart';
import 'package:test/test.dart';

void main() {
  test('a game in progress round-trips through a store', () async {
    var game = BlockGame.newGame(23);
    final piece = game.hand[0]!;
    game = (game.place(0, const Coord(3, 3)) as PlacementAccepted).game;

    final store = GameStore(MemoryStore());
    await store.save(game, slot: 'current');
    final restored =
        await store.load('blockblast', BlockGame.fromJson, slot: 'current');

    expect(restored, isNotNull);
    expect(restored!.board, game.board);
    expect(restored.hand, game.hand);
    expect(restored.score, game.score);
    expect(restored.seed, game.seed);
    expect(restored.board.paintAt(const Coord(3, 3)), piece.paint);
  });

  test('a restored game deals on from where it left off', () {
    // The seed travels with the save, so resuming keeps the run it was on
    // rather than starting a fresh sequence of shapes.
    var game = BlockGame.newGame(77);
    for (var index = 0; index < handSize; index++) {
      final anchors = game.board.anchorsFor(game.hand[index]!.shape);
      game = (game.place(index, anchors.first) as PlacementAccepted).game;
    }
    final restored = BlockGame.fromJson(game.toJson());
    expect(restored.hand, game.hand);

    final next = restored.hand[0]!;
    final anchors = restored.board.anchorsFor(next.shape);
    expect(
      (restored.place(0, anchors.first) as PlacementAccepted).game.hand,
      (game.place(0, anchors.first) as PlacementAccepted).game.hand,
    );
  });

  test('a played-out slot is remembered as played out', () async {
    var game = BlockGame.newGame(5);
    game = (game.place(0, const Coord(0, 0)) as PlacementAccepted).game;
    expect(game.hand[0], isNull);

    final restored = BlockGame.fromJson(game.toJson());
    expect(restored.hand[0], isNull);
    expect(restored.remaining, hasLength(handSize - 1));
  });

  test('the game id is stable', () {
    expect(BlockGame.newGame(1).gameId, 'blockblast');
  });

  test('a corrupt record costs the game, not the app', () async {
    final store = MemoryStore();
    await GameStore(store).save(BlockGame.newGame(1), slot: 'current');
    await store.write(
      GameStore.keyFor('blockblast', 'current'),
      '{"version":1,"gameId":"blockblast","slot":"current","state":{}}',
    );

    expect(
      await GameStore(store)
          .load('blockblast', BlockGame.fromJson, slot: 'current'),
      isNull,
    );
    expect(
      await GameStore(store).has('blockblast', slot: 'current'),
      isFalse,
      reason: 'the bad record should have been cleared on the way out',
    );
  });

  test('malformed game JSON is refused', () {
    final good = BlockGame.newGame(1).toJson();
    for (final broken in <Map<String, Object?>>[
      <String, Object?>{...good, 'score': 'lots'},
      <String, Object?>{...good, 'seed': null},
      <String, Object?>{...good, 'hand': <Object?>[null]},
      <String, Object?>{...good, 'hand': <Object?>[1, 2, 3]},
      <String, Object?>{...good, 'board': <Object?>[]},
    ]) {
      expect(
        () => BlockGame.fromJson(broken),
        throwsFormatException,
        reason: '$broken',
      );
    }
  });
}
