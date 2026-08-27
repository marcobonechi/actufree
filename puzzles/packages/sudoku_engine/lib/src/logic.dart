import 'candidate_grid.dart';
import 'deduction.dart';
import 'technique.dart';
import 'techniques.dart';

/// Applies techniques to [grid] until it is solved or nothing more is found,
/// tallying each application into [counts].
///
/// Returns `false` only when a step exposes a contradiction. Running out of
/// applicable techniques is not a failure — the caller decides whether to
/// start guessing, which is the difference between solving a puzzle and
/// asking how hard it is.
///
/// [allowed] restricts which techniques may be used; `null` allows all of
/// them.
bool runLogic(
  CandidateGrid grid,
  Map<Technique, int> counts, {
  Set<Technique>? allowed,
}) {
  while (!grid.isSolved) {
    Deduction? found;
    for (final finder in orderedFinders) {
      if (allowed != null && !allowed.contains(finder.technique)) continue;
      found = finder.find(grid);
      if (found != null) break;
    }
    if (found == null) return true;
    counts.update(found.technique, (value) => value + 1, ifAbsent: () => 1);
    if (!found.applyTo(grid)) return false;
  }
  return true;
}
