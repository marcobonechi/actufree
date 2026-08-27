/// A solving technique, ordered from most to least elementary.
///
/// The order is significant: difficulty is rated from the hardest technique a
/// puzzle forces the solver to reach for, so these must stay sorted by
/// increasing difficulty.
enum Technique {
  /// A cell has exactly one candidate left.
  nakedSingle('Naked single'),

  /// A digit has exactly one place left in a unit.
  hiddenSingle('Hidden single'),

  /// Two cells in a unit share the same two candidates, excluding those
  /// digits from the rest of the unit.
  nakedPair('Naked pair'),

  /// Two digits are confined to the same two cells of a unit, excluding
  /// every other candidate from those cells.
  hiddenPair('Hidden pair'),

  /// Three cells in a unit between them hold only three candidates.
  nakedTriple('Naked triple'),

  /// A digit's candidates within a box all lie on one row or column, so it
  /// can be excluded from the rest of that line.
  pointingPair('Pointing pair'),

  /// A digit's candidates within a row or column all lie in one box, so it
  /// can be excluded from the rest of that box.
  boxLineReduction('Box/line reduction'),

  /// A digit occupies the same two columns in two rows (or vice versa).
  xWing('X-wing'),

  /// A pivot cell with two candidates sees two pincers that share a digit.
  yWing('Y-wing'),

  /// No logical step was available; the value was found by trial and error.
  guess('Guess');

  const Technique(this.label);

  /// A short human-readable name, suitable for a hint dialog.
  final String label;
}
