/// How a placement earns points.
///
/// Kept apart from the game so the rule can be read, and tested, in one place
/// rather than inferred from wherever a running total is kept.
abstract final class Scoring {
  /// Points for each cell of the placed shape.
  ///
  /// Small on purpose. It is there so a placement that clears nothing still
  /// registers, not so a player can win by dropping 1x1s.
  static const int perCell = 1;

  /// The base value of one cleared line.
  static const int perLine = 10;

  /// What a placement of [cells] cells clearing [lines] lines is worth.
  ///
  /// Lines are worth [perLine] each, multiplied again by how many came out at
  /// once: one line is 10, two are 40, three are 90, four are 160. The square
  /// is the whole reason to build towards a double rather than take every
  /// single as it appears.
  static int forPlacement({required int cells, required int lines}) =>
      cells * perCell + lines * lines * perLine;
}
