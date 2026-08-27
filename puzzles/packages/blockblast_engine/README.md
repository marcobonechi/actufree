# blockblast_engine

The rules of Block Blast, as pure Dart: an 8x8 board, a catalogue of shapes, a
hand of three, placement, line clearing, scoring and dealing.

No Flutter imports, by design — the engine knows the game and nothing about how
it is drawn. Run its tests with `dart test`, no simulator involved.
