import 'technique.dart';

/// The named difficulty tiers offered to the player.
enum Difficulty {
  /// Solvable with singles alone.
  easy('Easy'),

  /// Needs subsets or locked candidates.
  medium('Medium'),

  /// Needs fish or wings.
  hard('Hard'),

  /// Cannot be solved by the implemented techniques alone.
  expert('Expert');

  const Difficulty(this.label);

  /// A short human-readable name.
  final String label;
}

/// How hard a puzzle is, and why.
///
/// The tier is derived from the techniques the logical solver had to reach for,
/// not from the clue count, which is a poor proxy — a 24-clue puzzle can be
/// easier than a 30-clue one.
final class DifficultyRating {
  /// Creates a rating.
  const DifficultyRating({
    required this.tier,
    required this.hardestTechnique,
    required this.techniquesUsed,
    required this.score,
  });

  /// The tier this puzzle falls into.
  final Difficulty tier;

  /// The most advanced technique the puzzle forced.
  ///
  /// [Technique.guess] means the logical solver stalled and the puzzle needed
  /// trial and error.
  final Technique hardestTechnique;

  /// How many times each technique was applied, in [Technique] order.
  final Map<Technique, int> techniquesUsed;

  /// A numeric score, useful for ordering two puzzles within one tier.
  final int score;
}
