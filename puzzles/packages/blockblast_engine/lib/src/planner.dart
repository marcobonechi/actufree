import 'coord.dart';
import 'game.dart';
import 'piece.dart';
import 'score.dart';

/// One step of a plan: which slot of the hand, and where it goes.
final class PlannedMove {
  /// Puts the piece in [handIndex] at [anchor].
  const PlannedMove(this.handIndex, this.anchor);

  /// The slot of the hand this step plays.
  final int handIndex;

  /// Where that piece's top-left corner goes.
  final Coord anchor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedMove &&
          other.handIndex == handIndex &&
          other.anchor == anchor;

  @override
  int get hashCode => Object.hash(handIndex, anchor);

  @override
  String toString() => 'PlannedMove($handIndex -> $anchor)';
}

/// A way to play out what is left of a hand.
final class HandPlan {
  /// Records a plan.
  const HandPlan({
    required this.moves,
    required this.lines,
    required this.points,
  });

  /// The steps, in the order they must be played.
  ///
  /// Order matters and is not incidental: a plan often works only because an
  /// earlier piece completed a line and got out of the way of a later one.
  final List<PlannedMove> moves;

  /// How many lines the whole plan takes out.
  final int lines;

  /// What the whole plan scores.
  final int points;

  /// Whether the plan gets every remaining piece onto the board.
  bool coversWholeHand(BlockGame game) => moves.length == game.remaining.length;

  @override
  String toString() => 'HandPlan($lines lines, $points points, $moves)';
}

/// Works out the best way to play the rest of a hand.
///
/// Searches every order the remaining pieces could be played in and every
/// square each could go on, which is far more than it sounds — but the whole
/// thing runs on a 64-bit board, one bit per square, so a placement is an AND
/// and an OR and clearing a line is a handful of masks. States that different
/// orders arrive at in common are worked out once and remembered, which is
/// what keeps it instant on a phone.
///
/// This is the one place in the engine that knows how to *play* rather than
/// how to referee, and it stays here rather than in the screen: it is rules
/// and arithmetic, it needs no widget, and it is far easier to be sure of in
/// a test than behind a button.
abstract final class HandPlanner {
  /// The best plan for [game], or `null` when nothing can be placed at all.
  ///
  /// Best means, in order: getting the most pieces down, then taking out the
  /// most lines, then scoring the most, then leaving the fewest holes. Lines
  /// come before score on purpose — a player asking for help with clearing
  /// wants lines gone, and score would sometimes rather have two at once than
  /// three apart.
  ///
  /// The holes matter more than they look. Better than a quarter of hands
  /// have nothing to clear at all, and without that last tie-break every plan
  /// for such a hand scores identically and the search hands back whichever
  /// it happened to try first — which is a corner, and which quietly teaches
  /// the player to wall themselves in.
  static HandPlan? bestFor(BlockGame game) {
    final pieces = <int, BlockPiece>{};
    for (var index = 0; index < game.hand.length; index++) {
      final piece = game.hand[index];
      if (piece != null) pieces[index] = piece;
    }
    if (pieces.isEmpty) return null;

    // Every square each piece could occupy, as a bitmask, worked out once
    // rather than at each of the thousands of nodes below.
    final placements = <int, List<(Coord, int)>>{};
    for (final entry in pieces.entries) {
      final shape = entry.value.shape;
      placements[entry.key] = <(Coord, int)>[
        for (var row = 0; row <= boardSize - shape.height; row++)
          for (var col = 0; col <= boardSize - shape.width; col++)
            (
              Coord(row, col),
              _maskOf(shape.cells.map((Coord c) => c.translate(row, col))),
            ),
      ];
    }

    var occupancy = 0;
    for (final coord in Coord.all) {
      if (game.board.isFilled(coord)) occupancy |= 1 << coord.index;
    }

    var remaining = 0;
    for (final index in pieces.keys) {
      remaining |= 1 << index;
    }

    final memo = <(int, int), _Suffix>{};
    final best = _bestFrom(occupancy, remaining, pieces, placements, memo);
    if (best.moves.isEmpty) return null;
    return HandPlan(
      moves: List<PlannedMove>.unmodifiable(best.moves),
      lines: best.lines,
      points: best.points,
    );
  }

  /// The best that can be done from [occupancy] with [remaining] still in
  /// hand.
  ///
  /// Memoised on the pair, which is the whole state: what the board looks like
  /// and what is left to play. Two different orders that reach the same board
  /// have exactly the same future, and there are a great many such pairs.
  static _Suffix _bestFrom(
    int occupancy,
    int remaining,
    Map<int, BlockPiece> pieces,
    Map<int, List<(Coord, int)>> placements,
    Map<(int, int), _Suffix> memo,
  ) {
    final key = (occupancy, remaining);
    final cached = memo[key];
    if (cached != null) return cached;

    // Playing nothing more from here is always an option, and it is the one
    // that fixes what the board is finally left looking like.
    var best = _Suffix(
      const <PlannedMove>[],
      0,
      0,
      _holes(occupancy),
    );
    for (final index in pieces.keys) {
      if (remaining & (1 << index) == 0) continue;
      final size = pieces[index]!.shape.size;
      for (final (anchor, mask) in placements[index]!) {
        if (occupancy & mask != 0) continue;
        final (cleared, lines) = _clear(occupancy | mask);
        final rest = _bestFrom(
          cleared,
          remaining & ~(1 << index),
          pieces,
          placements,
          memo,
        );
        final candidate = _Suffix(
          <PlannedMove>[PlannedMove(index, anchor), ...rest.moves],
          lines + rest.lines,
          Scoring.forPlacement(cells: size, lines: lines) + rest.points,
          rest.holes,
        );
        if (candidate.beats(best)) best = candidate;
      }
    }
    return memo[key] = best;
  }

  /// The bits [cells] occupy.
  static int _maskOf(Iterable<Coord> cells) {
    var mask = 0;
    for (final cell in cells) {
      mask |= 1 << cell.index;
    }
    return mask;
  }

  /// How many empty squares on [occupancy] are boxed in on all four sides.
  ///
  /// A square with filled squares or the edge of the board on every side can
  /// only ever be used by a 1x1, which is the rarest piece there is. Counting
  /// them is a cheap stand-in for how workable a board has been left.
  static int _holes(int occupancy) {
    final empty = ~occupancy;
    // Off the board counts as filled: a square against the wall is not open
    // in that direction.
    final above = (occupancy << boardSize) | _rowMasks.first;
    final below = (occupancy >> boardSize) | _rowMasks.last;
    final left = ((occupancy << 1) & ~_colMasks.first) | _colMasks.first;
    final right = ((occupancy >> 1) & ~_colMasks.last) | _colMasks.last;
    var boxedIn = empty & above & below & left & right;

    var count = 0;
    while (boxedIn != 0) {
      boxedIn &= boxedIn - 1;
      count++;
    }
    return count;
  }

  /// [occupancy] with its full rows and columns emptied, and how many went.
  static (int, int) _clear(int occupancy) {
    var going = 0;
    var lines = 0;
    for (var i = 0; i < boardSize; i++) {
      final row = _rowMasks[i];
      if (occupancy & row == row) {
        going |= row;
        lines++;
      }
      final col = _colMasks[i];
      if (occupancy & col == col) {
        going |= col;
        lines++;
      }
    }
    return (occupancy & ~going, lines);
  }
}

/// The best that can be played from some point onwards.
final class _Suffix {
  const _Suffix(this.moves, this.lines, this.points, this.holes);

  final List<PlannedMove> moves;
  final int lines;
  final int points;

  /// Boxed-in empty squares on the board this leaves behind.
  final int holes;

  /// Whether this is the better of the two: more pieces down first, then more
  /// lines, then more points, then a board left in a better state.
  bool beats(_Suffix other) {
    if (moves.length != other.moves.length) {
      return moves.length > other.moves.length;
    }
    if (lines != other.lines) return lines > other.lines;
    if (points != other.points) return points > other.points;
    return holes < other.holes;
  }
}

final List<int> _rowMasks = List<int>.generate(
  boardSize,
  (int row) => 0xFF << (row * boardSize),
  growable: false,
);

// The board is a 64-bit bitboard, one bit per cell. dart2js cannot represent
// a literal this wide — JavaScript integers carry 53 bits of precision — so
// the seed is assembled at runtime instead. The wasm build, which is the only
// web build we ship, computes the exact value; a JS build would compute a
// wrong one, which is why web/flutter_bootstrap.js refuses to fall back to it.
final int _colSeed = (0x01010101 << 32) | 0x01010101;

final List<int> _colMasks = List<int>.generate(
  boardSize,
  (int col) => _colSeed << col,
  growable: false,
);
