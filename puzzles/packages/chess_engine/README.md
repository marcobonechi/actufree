# chess_engine

The rules of chess, as pure Dart: the board, move generation, legality, check
and mate, the drawing rules, algebraic notation, and the history a game of two
players needs in order to take a move back.

It also holds the computer player — an evaluation and an alpha-beta search with
a quiescence extension, at three levels. That lives here rather than in the app
because it is pure logic and it is the part most worth testing: a test of it
should not need a screen.

No Flutter imports, by design. Run the tests with `dart test`, no simulator
involved.

Two tools, for the numbers that should not be guesses:

- `dart run tool/measure_perft.dart` counts the move tree and checks it against
  the published figures. The starting position matches at depth five and
  Kiwipete at depth four.
- `dart run tool/measure_bot.dart` times the computer at each level, which is
  where `BotLevel`'s ceilings come from. Re-run it before changing them.
