// Measures how long the computer takes to move and how much of that is spent
// where, so the levels are set from numbers rather than from a guess.
//
// Run with: dart run tool/measure_bot.dart
import 'package:chess_engine/chess_engine.dart';

const Map<String, String> positions = <String, String>{
  'opening': startingFen,
  'middlegame':
      'r1bq1rk1/pp2bppp/2n1pn2/2pp4/3P1B2/2PBPN2/PP1N1PPP/R2Q1RK1 w - - 0 9',
  'tactical':
      'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
  'endgame': '8/5pk1/6p1/8/5PK1/8/6P1/3R4 w - - 0 1',
};

void main() {
  for (final level in BotLevel.values) {
    print('--- ${level.label} (depth ${level.maxDepth}, '
        '${level.maxNodes} nodes) ---');
    positions.forEach((String name, String fen) {
      final clock = Stopwatch()..start();
      final result = ChessBot(level: level).think(Position.fromFen(fen));
      final ms = clock.elapsedMilliseconds;
      final rate = ms == 0 ? 0 : (result!.nodes / ms).round();
      print('  $name: ${result!.move.uci} in $ms ms '
          '(depth ${result.depth}, ${result.nodes} nodes, ${rate}k/s)');
    });
  }
}
