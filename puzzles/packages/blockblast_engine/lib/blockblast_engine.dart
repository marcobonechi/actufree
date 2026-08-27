/// The rules of Block Blast: an 8x8 board, a catalogue of shapes, a hand of
/// three, placement, line clearing, scoring and dealing.
///
/// This library deliberately has no Flutter dependency. It knows the rules of
/// the game and nothing about how it is drawn.
library;

export 'src/board.dart';
export 'src/catalogue.dart';
export 'src/coord.dart';
export 'src/dealer.dart';
export 'src/game.dart';
export 'src/piece.dart';
export 'src/placement.dart';
export 'src/score.dart';
export 'src/shape.dart';
