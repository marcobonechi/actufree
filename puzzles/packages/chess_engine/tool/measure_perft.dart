// Counts the move tree below a position and says how long it took, so the
// depth the tests can afford is a measured number rather than a guess.
//
// Run with: dart run tool/measure_perft.dart
import 'package:chess_engine/chess_engine.dart';

/// The leaves of the move tree [depth] plies below [position].
int perft(Position position, int depth) {
  if (depth == 0) return 1;
  if (depth == 1) return position.legalMoves.length;
  var nodes = 0;
  for (final move in position.legalMoves) {
    nodes += perft(position.makeMove(move), depth - 1);
  }
  return nodes;
}

void main() {
  const positions = <String, String>{
    'start': startingFen,
    'kiwipete':
        'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
  };
  positions.forEach((String name, String fen) {
    final position = Position.fromFen(fen);
    for (var depth = 1; depth <= 5; depth++) {
      final clock = Stopwatch()..start();
      final nodes = perft(position, depth);
      final ms = clock.elapsedMilliseconds;
      final rate = ms == 0 ? '' : ' — ${(nodes / ms).round()}k nodes/s';
      print('$name depth $depth: $nodes in $ms ms$rate');
      if (ms > 20000) break;
    }
  });
}
