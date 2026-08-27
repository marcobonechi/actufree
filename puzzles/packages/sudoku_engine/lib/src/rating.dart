import 'difficulty.dart';
import 'technique.dart';

/// The tier a puzzle lands in when [technique] is the hardest step it forces.
Difficulty tierOf(Technique technique) {
  switch (technique) {
    case Technique.nakedSingle:
    case Technique.hiddenSingle:
      return Difficulty.easy;
    case Technique.nakedPair:
    case Technique.hiddenPair:
    case Technique.nakedTriple:
    case Technique.pointingPair:
    case Technique.boxLineReduction:
      return Difficulty.medium;
    case Technique.xWing:
    case Technique.yWing:
      return Difficulty.hard;
    case Technique.guess:
      return Difficulty.expert;
  }
}

/// Every technique a puzzle of [tier] is allowed to need.
List<Technique> techniquesUpTo(Difficulty tier) => Technique.values
    .where((technique) => tierOf(technique).index <= tier.index)
    .toList();

/// How much one application of [technique] contributes to the score.
///
/// Only used to order two puzzles within the same tier, so the exact numbers
/// matter less than their relative spacing.
int weightOf(Technique technique) {
  switch (technique) {
    case Technique.nakedSingle:
      return 1;
    case Technique.hiddenSingle:
      return 2;
    case Technique.pointingPair:
    case Technique.boxLineReduction:
      return 5;
    case Technique.nakedPair:
      return 6;
    case Technique.hiddenPair:
      return 8;
    case Technique.nakedTriple:
      return 10;
    case Technique.xWing:
      return 20;
    case Technique.yWing:
      return 24;
    case Technique.guess:
      return 60;
  }
}

/// Builds a rating from how often each technique was applied.
DifficultyRating ratingFrom(Map<Technique, int> counts) {
  final ordered = <Technique, int>{};
  var hardest = Technique.nakedSingle;
  var score = 0;
  for (final technique in Technique.values) {
    final count = counts[technique];
    if (count == null || count == 0) continue;
    ordered[technique] = count;
    hardest = technique;
    score += weightOf(technique) * count;
  }
  return DifficultyRating(
    tier: tierOf(hardest),
    hardestTechnique: hardest,
    techniquesUsed: Map<Technique, int>.unmodifiable(ordered),
    score: score,
  );
}
