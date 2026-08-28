import 'dart:isolate';

import 'package:chess_engine/chess_engine.dart';

/// Works out the computer's move in [position].
///
/// Returns `null` when there is nothing to play, which is a finished game.
typedef MoveChooser = Future<Move?> Function(
  Position position,
  BotLevel level,
  Set<String> history,
  int seed,
);

/// Thinks on another thread, and hands back the move.
///
/// The search runs in an isolate because it takes a second at the top level,
/// and a second is a very long time to hold still a board that the player can
/// see. Nothing about the engine makes this hard: it is pure Dart with no
/// Flutter in it, so what crosses between the two threads is a position
/// written as text and a move written as text.
Future<Move?> chooseMoveOffThread(
  Position position,
  BotLevel level,
  Set<String> history,
  int seed,
) async {
  final fen = position.toFen();
  final uci = await Isolate.run(() {
    final result = ChessBot(level: level, seed: seed)
        .think(Position.fromFen(fen), history: history);
    return result?.move.uci;
  });
  // Parsed against the position held here rather than trusted: what comes
  // back is four characters of text, and the board is about to be told to
  // play it.
  return uci == null ? null : parseUci(position, uci);
}
