import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:test/test.dart';

/// A game in an arbitrary state, built through the save format.
BlockGame gameWith({
  required BlockBoard board,
  required List<BlockPiece?> hand,
}) {
  return BlockGame.fromJson(<String, Object?>{
    'board': board.toJson(),
    'hand': <Object?>[for (final piece in hand) piece?.toJson()],
    'score': 0,
    'seed': 1,
  });
}

/// Plays [plan] out and reports what really happened.
(int lines, int points, int placed) playOut(BlockGame game, HandPlan plan) {
  var current = game;
  var lines = 0;
  var points = 0;
  var placed = 0;
  for (final move in plan.moves) {
    final result = current.place(move.handIndex, move.anchor);
    expect(result, isA<PlacementAccepted>(), reason: '$move');
    final accepted = result as PlacementAccepted;
    lines += accepted.clear.lineCount;
    points += accepted.points;
    placed++;
    current = accepted.game;
  }
  return (lines, points, placed);
}

void main() {
  final single = BlockShape.fromRows(<String>['#']);
  final domino = BlockShape.fromRows(<String>['##']);
  final square = BlockShape.fromRows(<String>['##', '##']);

  test('an empty hand has no plan', () {
    final game = gameWith(
      board: BlockBoard.empty(),
      hand: <BlockPiece?>[null, null, null],
    );
    expect(HandPlanner.bestFor(game), isNull);
  });

  test('a hand with nowhere to go has no plan', () {
    final game = gameWith(
      board: BlockBoard.fromRows(<String>[
        '1111111.',
        '11111111',
        '11111111',
        '11111111',
        '11111111',
        '11111111',
        '11111111',
        '11111111',
      ]),
      hand: <BlockPiece?>[BlockPiece(square, 1), null, null],
    );
    expect(HandPlanner.bestFor(game), isNull);
  });

  test('it plays every piece it can', () {
    final game = gameWith(
      board: BlockBoard.empty(),
      hand: <BlockPiece?>[
        BlockPiece(square, 1),
        BlockPiece(domino, 2),
        BlockPiece(single, 3),
      ],
    );
    final plan = HandPlanner.bestFor(game)!;
    expect(plan.moves, hasLength(3));
    expect(plan.coversWholeHand(game), isTrue);
    expect(
      plan.moves.map((PlannedMove m) => m.handIndex).toSet(),
      <int>{0, 1, 2},
      reason: 'each piece exactly once',
    );
  });

  test('the plan does what it says it will', () {
    for (var seed = 0; seed < 60; seed++) {
      var game = BlockGame.newGame(seed);
      // Part way into a run, where the board has something on it.
      for (var move = 0; move < 12 && !game.isOver; move++) {
        final index =
            game.hand.indexWhere((BlockPiece? p) => p != null &&
                game.board.fitsAnywhere(p.shape));
        final anchors = game.board.anchorsFor(game.hand[index]!.shape);
        game = (game.place(index, anchors.first) as PlacementAccepted).game;
      }
      if (game.isOver) continue;

      final plan = HandPlanner.bestFor(game)!;
      final played = playOut(game, plan);
      expect(played.$1, plan.lines, reason: 'seed $seed lines');
      expect(played.$2, plan.points, reason: 'seed $seed points');
      expect(played.$3, plan.moves.length, reason: 'seed $seed placed');
    }
  });

  test('it finds a clear that only one order allows', () {
    // Row 7 is two cells short at columns 6 and 7. The square cannot reach
    // them, so the domino has to go first — and the square then needs the
    // room the clear leaves behind.
    final game = gameWith(
      board: BlockBoard.fromRows(<String>[
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '11111111',
        '111111..',
      ]),
      hand: <BlockPiece?>[BlockPiece(square, 1), BlockPiece(domino, 2), null],
    );
    final plan = HandPlanner.bestFor(game)!;
    expect(plan.moves, hasLength(2));
    expect(plan.lines, greaterThanOrEqualTo(1));
    expect(playOut(game, plan).$1, plan.lines);
  });

  test('it takes two lines at once when two are there to take', () {
    // Both bottom rows are one cell short, in the same column. A vertical
    // domino down that column takes them both; anything else takes one.
    final vertical = BlockShape.fromRows(<String>['#', '#']);
    final game = gameWith(
      board: BlockBoard.fromRows(<String>[
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '1111111.',
        '1111111.',
      ]),
      hand: <BlockPiece?>[BlockPiece(vertical, 1), null, null],
    );
    final plan = HandPlanner.bestFor(game)!;
    expect(plan.lines, 2);
    expect(plan.moves.single.anchor, const Coord(6, 7));
    expect(plan.points, Scoring.forPlacement(cells: 2, lines: 2));
  });

  test('with nothing to clear it still avoids boxing squares in', () {
    // r3c3 is open on one side only. Dropping the 1x1 into that side walls it
    // off for good — a square only the rarest piece in the catalogue can ever
    // use again. Every other square scores exactly the same, so nothing but
    // the tie-break separates them.
    final board = BlockBoard.fromRows(<String>[
      '........',
      '..1.....',
      '.1......',
      '..1.....',
      '........',
      '........',
      '........',
      '........',
    ]);
    final game = gameWith(
      board: board,
      hand: <BlockPiece?>[BlockPiece(single, 1), null, null],
    );

    int boxedIn(BlockBoard b) {
      var count = 0;
      for (final coord in Coord.all) {
        if (b.isFilled(coord)) continue;
        final open = <Coord>[
          coord.translate(-1, 0),
          coord.translate(1, 0),
          coord.translate(0, -1),
          coord.translate(0, 1),
        ].where((Coord n) => n.isOnBoard && !b.isFilled(n));
        if (open.isEmpty) count++;
      }
      return count;
    }

    expect(boxedIn(board), 0, reason: 'the board starts with none');
    final plan = HandPlanner.bestFor(game)!;
    expect(plan.moves.single.anchor, isNot(const Coord(2, 3)));
    final played =
        (game.place(0, plan.moves.single.anchor) as PlacementAccepted).game;
    expect(boxedIn(played.board), 0, reason: 'walled a square off for nothing');
  });

  test('planning a hand stays quick enough to sit behind a button', () {
    // The costly case is an open board, where every piece has a great many
    // squares to try — and, ironically, nothing to clear. A generous bound:
    // this is guarding against a regression that makes it seconds, not
    // measuring the machine.
    var worst = 0;
    for (var seed = 0; seed < 40; seed++) {
      var game = BlockGame.newGame(seed);
      var moves = 0;
      while (!game.isOver && moves < 20) {
        final watch = Stopwatch()..start();
        HandPlanner.bestFor(game);
        watch.stop();
        if (watch.elapsedMicroseconds > worst) {
          worst = watch.elapsedMicroseconds;
        }
        final index = game.hand.indexWhere((BlockPiece? p) =>
            p != null && game.board.fitsAnywhere(p.shape));
        final anchors = game.board.anchorsFor(game.hand[index]!.shape);
        game = (game.place(index, anchors.first) as PlacementAccepted).game;
        moves++;
      }
    }
    expect(worst, lessThan(400000), reason: '${worst ~/ 1000}ms worst case');
  });

  test('it never does worse than taking the best move each turn', () {
    // Greedy takes the most lines available right now; the plan looks at the
    // whole hand. Compared on the plan's own terms — pieces down first, then
    // lines — the plan can never come off worse, and sometimes comes off
    // better, which is the entire reason to look ahead.
    var better = 0;
    for (var seed = 0; seed < 120; seed++) {
      var game = BlockGame.newGame(seed);
      for (var move = 0; move < 16 && !game.isOver; move++) {
        final index = game.hand.indexWhere((BlockPiece? p) =>
            p != null && game.board.fitsAnywhere(p.shape));
        final anchors = game.board.anchorsFor(game.hand[index]!.shape);
        game = (game.place(index, anchors.first) as PlacementAccepted).game;
      }
      if (game.isOver) continue;
      final plan = HandPlanner.bestFor(game)!;

      var greedy = game;
      var greedyLines = 0;
      var greedyPlaced = 0;
      // Only this hand. Playing the last piece deals another one, and letting
      // greedy carry on into it would be comparing three placements against
      // however many it felt like.
      final inHand = game.remaining.length;
      while (greedyPlaced < inHand) {
        var bestLines = -1;
        var bestIndex = -1;
        Coord? bestAnchor;
        for (var i = 0; i < handSize; i++) {
          final piece = greedy.hand[i];
          if (piece == null) continue;
          for (final anchor in greedy.board.anchorsFor(piece.shape)) {
            final lines = (greedy.place(i, anchor) as PlacementAccepted)
                .clear
                .lineCount;
            if (lines > bestLines) {
              bestLines = lines;
              bestIndex = i;
              bestAnchor = anchor;
            }
          }
        }
        if (bestAnchor == null) break;
        greedyLines += bestLines;
        greedyPlaced++;
        greedy =
            (greedy.place(bestIndex, bestAnchor) as PlacementAccepted).game;
      }

      final planIsWorse = plan.moves.length < greedyPlaced ||
          (plan.moves.length == greedyPlaced && plan.lines < greedyLines);
      expect(planIsWorse, isFalse, reason: 'seed $seed');
      if (plan.moves.length > greedyPlaced || plan.lines > greedyLines) {
        better++;
      }
    }
    expect(better, greaterThan(0), reason: 'looking ahead never once paid off');
  });
}
