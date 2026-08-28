// Measures how a run actually goes: how fast the board fills, how often a
// hand can take a line out, and whether the board is ever swept clean.
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

void main(List<String> args) {
  final games = args.isEmpty ? 800 : int.parse(args.first);
  for (final player in <(String, (int, Coord) Function(BlockGame, Random))>[
    ('careless', careless),
    ('greedy', greedy),
  ]) {
    final random = Random(7);
    final lengths = <int>[];
    var scoreTotal = 0;
    var cellsPlaced = 0;
    var cellsCleared = 0;
    var linesCleared = 0;
    var deals = 0;
    var dealsWithAClearer = 0;
    var dealsAllClearers = 0;
    var sweeps = 0;
    var fillSum = 0.0;
    var fillSamples = 0;

    for (var seed = 0; seed < games; seed++) {
      var game = BlockGame.newGame(seed);
      var sweptThisGame = false;
      var moveCount = 0;

      void noteDeal(BlockGame g) {
        deals++;
        final clearers =
            g.remaining.where((BlockPiece p) => g.board.canClearWith(p.shape));
        if (clearers.isNotEmpty) dealsWithAClearer++;
        if (clearers.length == handSize) dealsAllClearers++;
      }

      noteDeal(game);
      while (!game.isOver) {
        final move = player.$2(game, random);
        final before = game;
        final result = before.place(move.$1, move.$2) as PlacementAccepted;
        cellsPlaced += before.hand[move.$1]!.shape.size;
        cellsCleared += result.clear.cells.length;
        linesCleared += result.clear.lineCount;
        game = result.game;
        moveCount++;
        fillSum += game.board.filledCount / cellCount;
        fillSamples++;
        if (game.board.isEmpty) sweptThisGame = true;
        if (result.dealt) noteDeal(game);
      }
      if (sweptThisGame) sweeps++;
      lengths.add(moveCount);
      scoreTotal += game.score;
    }

    lengths.sort();
    String pct(num n, num of) => '${(100 * n / of).toStringAsFixed(1)}%';
    print('--- ${player.$1}  ($games games)');
    print('  moves   mean ${(lengths.reduce((a, b) => a + b) / games).toStringAsFixed(1)}'
        '   median ${lengths[games ~/ 2]}'
        '   p90 ${lengths[(games * 0.9).floor()]}');
    print('  score   mean ${(scoreTotal / games).toStringAsFixed(0)}');
    print('  cells   placed/hand ${(3 * cellsPlaced / (deals * handSize)).toStringAsFixed(1)}'
        '   cleared/hand ${(3 * cellsCleared / (deals * handSize)).toStringAsFixed(1)}');
    print('  lines   per game ${(linesCleared / games).toStringAsFixed(1)}');
    print('  board   average fill ${pct(fillSum, fillSamples)}');
    print('  hands with a piece that can clear   ${pct(dealsWithAClearer, deals)}');
    print('  hands where all three can clear     ${pct(dealsAllClearers, deals)}');
    print('  games that swept the board clean    ${pct(sweeps, games)}');
  }
}
