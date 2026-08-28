// Measures how often a dealt hand runs out of playable pieces.
//
// Run with: dart run tool/measure_dealer.dart
import 'dart:math';

import 'package:blockblast_engine/blockblast_engine.dart';

/// Every legal move available in [game].
List<(int, Coord)> moves(BlockGame game) => <(int, Coord)>[
      for (var i = 0; i < handSize; i++)
        if (game.hand[i] != null)
          for (final anchor in game.board.anchorsFor(game.hand[i]!.shape))
            (i, anchor),
    ];

/// A mediocre-but-sane player: take the biggest clear, otherwise pack towards
/// a corner rather than scattering pieces across the middle.
(int, Coord) greedy(BlockGame game, Random _) {
  var best = moves(game).first;
  var bestScore = -1 << 30;
  for (final move in moves(game)) {
    final result = game.place(move.$1, move.$2) as PlacementAccepted;
    final score = result.clear.lineCount * 1000 + move.$2.row + move.$2.col;
    if (score > bestScore) {
      bestScore = score;
      best = move;
    }
  }
  return best;
}

/// A player with no plan at all.
(int, Coord) careless(BlockGame game, Random random) {
  final legal = moves(game);
  return legal[random.nextInt(legal.length)];
}

void main() {
  const games = 1500;
  for (final player in <(String, (int, Coord) Function(BlockGame, Random))>[
    ('careless', careless),
    ('greedy', greedy),
  ]) {
    final random = Random(7);
    var moveCount = 0;
    var scoreTotal = 0;
    var deals = 0;
    final fitAtDeal = <int, int>{0: 0, 1: 0, 2: 0, 3: 0};
    final leftOver = <int, int>{0: 0, 1: 0, 2: 0, 3: 0};
    var handsPlayedOut = 0;
    var handsAbandoned = 0;

    for (var seed = 0; seed < games; seed++) {
      var game = BlockGame.newGame(seed);
      var played = 0;
      deals++;
      fitAtDeal[game.remaining
          .where((BlockPiece p) => game.board.fitsAnywhere(p.shape))
          .length] = fitAtDeal[game.remaining
              .where((BlockPiece p) => game.board.fitsAnywhere(p.shape))
              .length]! +
          1;

      while (!game.isOver) {
        final move = player.$2(game, random);
        final before = game;
        game = (game.place(move.$1, move.$2) as PlacementAccepted).game;
        moveCount++;
        played++;
        // A new hand arrived: count how many of it fits the board it landed on.
        if (game.remaining.length == handSize && before.remaining.length == 1) {
          deals++;
          handsPlayedOut++;
          played = 0;
          final fits = game.remaining
              .where((BlockPiece p) => game.board.fitsAnywhere(p.shape))
              .length;
          fitAtDeal[fits] = fitAtDeal[fits]! + 1;
        }
      }
      if (played > 0) handsAbandoned++;
      leftOver[game.remaining.length] = leftOver[game.remaining.length]! + 1;
      scoreTotal += game.score;
    }

    print('--- ${player.$1}');
    print('  moves per game        ${(moveCount / games).toStringAsFixed(1)}');
    print('  score per game        ${(scoreTotal / games).toStringAsFixed(0)}');
    print('  hands dealt           $deals');
    for (final n in <int>[3, 2, 1]) {
      final pct = 100 * fitAtDeal[n]! / deals;
      print('  hands where $n of 3 fit when dealt   '
          '${pct.toStringAsFixed(1)}%');
    }
    for (final n in <int>[2, 1, 0]) {
      final pct = 100 * leftOver[n]! / games;
      print('  games ending with $n pieces in hand  '
          '${pct.toStringAsFixed(1)}%');
    }
    print('  hands played out fully  $handsPlayedOut');
    print('  runs ending mid-hand    $handsAbandoned');
  }
}
