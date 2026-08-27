import 'candidate_grid.dart';
import 'tables.dart';
import 'technique.dart';

/// One logical step: either a digit that can be placed, or candidates that can
/// be ruled out.
///
/// Indices are raw cell indices; the public [Hint] types wrap these in [Cell]s.
final class Deduction {
  /// A step that places [placementDigit] in [placementIndex].
  const Deduction.placement({
    required this.technique,
    required this.explanation,
    required this.because,
    required int index,
    required int digit,
  })  : placementIndex = index,
        placementDigit = digit,
        eliminations = const <int, int>{};

  /// A step that rules out candidates.
  ///
  /// [eliminations] maps a cell index to the bitmask of digits to strike.
  const Deduction.elimination({
    required this.technique,
    required this.explanation,
    required this.because,
    required this.eliminations,
  })  : placementIndex = null,
        placementDigit = null;

  /// The technique that justifies this step.
  final Technique technique;

  /// A sentence describing the step.
  final String explanation;

  /// The cells that make the deduction work, for highlighting.
  final Set<int> because;

  /// The cell to fill, when this is a placement.
  final int? placementIndex;

  /// The digit to place, when this is a placement.
  final int? placementDigit;

  /// The candidates to strike, when this is an elimination.
  final Map<int, int> eliminations;

  /// Whether this step places a digit rather than ruling candidates out.
  bool get isPlacement => placementIndex != null;

  /// Applies this step to [grid].
  ///
  /// Returns `false` when the step exposes a contradiction.
  bool applyTo(CandidateGrid grid) {
    final index = placementIndex;
    if (index != null) return grid.place(index, placementDigit!);
    for (final entry in eliminations.entries) {
      for (final digit in digitsOf(entry.value)) {
        if (!grid.eliminate(entry.key, digit)) return false;
      }
    }
    return true;
  }
}
