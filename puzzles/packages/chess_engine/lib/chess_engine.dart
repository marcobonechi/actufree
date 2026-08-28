/// The rules of chess: the board, the pieces, move generation, check and mate,
/// the drawing rules, algebraic notation and the history a game needs in order
/// to take a move back.
///
/// This library deliberately has no Flutter dependency. It knows the rules of
/// the game and nothing about how it is drawn.
///
/// It also holds the computer player: an evaluation, and a search that picks a
/// move with it. That lives here rather than in the app for the same reason
/// the rules do — it is pure logic, it is the part most worth testing, and a
/// test of it should not need a screen.
library;

export 'src/chess_save.dart';
export 'src/evaluation.dart';
export 'src/game.dart';
export 'src/move.dart';
export 'src/notation.dart';
export 'src/opponent.dart';
export 'src/outcome.dart';
export 'src/piece.dart';
export 'src/position.dart';
export 'src/search.dart';
export 'src/square.dart';
