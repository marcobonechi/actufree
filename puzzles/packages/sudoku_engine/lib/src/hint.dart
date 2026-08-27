import 'cell.dart';
import 'technique.dart';

/// The next logically deducible step, and the reasoning behind it.
sealed class Hint {
  const Hint(this.technique, this.explanation);

  /// The technique that justifies this step.
  final Technique technique;

  /// A sentence the UI can show as-is.
  final String explanation;
}

/// A digit that can be placed with certainty.
final class PlacementHint extends Hint {
  /// Creates a placement hint.
  const PlacementHint({
    required Technique technique,
    required String explanation,
    required this.cell,
    required this.digit,
    required this.because,
  }) : super(technique, explanation);

  /// The cell to fill.
  final Cell cell;

  /// The digit to write there.
  final int digit;

  /// The cells that make this deduction work, for highlighting.
  final Set<Cell> because;
}

/// A candidate that can be ruled out, when no placement is available yet.
final class EliminationHint extends Hint {
  /// Creates an elimination hint.
  const EliminationHint({
    required Technique technique,
    required String explanation,
    required this.eliminations,
    required this.because,
  }) : super(technique, explanation);

  /// The digits that can be ruled out, per cell.
  final Map<Cell, Set<int>> eliminations;

  /// The cells that make this deduction work, for highlighting.
  final Set<Cell> because;
}
