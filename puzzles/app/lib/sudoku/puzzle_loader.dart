import 'package:flutter/foundation.dart';
import 'package:sudoku_engine/sudoku_engine.dart';

/// Generates a puzzle off the UI thread.
///
/// A hard puzzle takes about 70ms to generate and can reach twice that, which
/// is enough dropped frames to be visible. The work is pure Dart with no
/// plugin calls, so it moves to a background isolate without ceremony.
///
/// The puzzle crosses the isolate boundary as its JSON form: plain maps, lists
/// and strings are unambiguously sendable, whereas the object graph would rely
/// on every field happening to be.
Future<SudokuPuzzle> generatePuzzle(Difficulty difficulty, int seed) async {
  final json = await compute(
    _generate,
    _Request(difficulty: difficulty, seed: seed),
  );
  return SudokuPuzzle.fromJson(json);
}

@immutable
class _Request {
  const _Request({required this.difficulty, required this.seed});

  final Difficulty difficulty;
  final int seed;
}

Map<String, Object?> _generate(_Request request) =>
    SudokuGenerator(request.seed).generate(request.difficulty).toJson();
