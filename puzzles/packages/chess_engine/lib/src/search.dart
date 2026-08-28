import 'dart:math';

import 'evaluation.dart';
import 'move.dart';
import 'position.dart';

/// How hard the computer plays.
///
/// Three tiers rather than a slider. A slider suggests the difference is one
/// dial being turned, and it is not: an easy opponent is not a strong one
/// thinking less, it is one that will let a mistake go by. Each tier is a
/// depth, a ceiling on how much work it may do, and how much worse than best a
/// move is allowed to be before it stops considering it.
enum BotLevel {
  /// Sees the move in front of it and little else. Will miss a hanging piece,
  /// and will let you take one back.
  easy('Easy', 'Misses things, and forgives them', maxDepth: 2, maxNodes: 30000, slack: 130),

  /// Plays soundly a few moves deep. Punishes a blunder, will not find a
  /// combination.
  medium('Medium', 'Solid, and takes what you leave', maxDepth: 4, maxNodes: 150000, slack: 40),

  /// Takes the best move it can find, every time.
  hard('Hard', 'Plays the best it can see', maxDepth: 7, maxNodes: 500000, slack: 0);

  const BotLevel(
    this.label,
    this.blurb, {
    required this.maxDepth,
    required this.maxNodes,
    required this.slack,
  });

  /// A short name for the player.
  final String label;

  /// A line saying what playing it is like.
  final String blurb;

  /// How many plies deep it will look.
  final int maxDepth;

  /// The most positions it may visit before answering with the best move it
  /// has so far.
  ///
  /// A ceiling on time, expressed as work rather than as seconds, so that the
  /// same position always produces the same move — on a fast phone, on a slow
  /// one, and in a test.
  ///
  /// The numbers come from `tool/measure_bot.dart`, which is worth re-running
  /// before changing them. Compiled ahead of time — which is how the app
  /// ships — the search manages between four hundred thousand and one and a
  /// half million positions a second on a laptop, and a phone is slower
  /// again. The ceilings are set so that the hardest level answers in about a
  /// second there, because past a second or two a player stops waiting and
  /// starts wondering whether the app has hung.
  ///
  /// Raising these buys depth, and depth is most of playing strength. If they
  /// are ever raised much, the thing to add first is a transposition table:
  /// the search currently looks at the same position many times over, and
  /// remembering what it made of it last time is worth more than any further
  /// tuning of these numbers.
  final int maxNodes;

  /// How far below the best a move may score and still be played, in
  /// centipawns.
  ///
  /// This is what makes an easy opponent playable rather than merely shallow.
  /// A search two plies deep already never hangs a queen, and a beginner who
  /// cannot win a single game does not keep playing.
  final int slack;
}

/// What the computer decided, and what it took.
final class SearchResult {
  /// Records a decision.
  const SearchResult({
    required this.move,
    required this.score,
    required this.depth,
    required this.nodes,
  });

  /// The move to play.
  final Move move;

  /// What it thinks of the position afterwards, in centipawns, from the point
  /// of view of the side that moved.
  final int score;

  /// How many plies deep the search actually finished.
  final int depth;

  /// How many positions it looked at.
  final int nodes;

  /// Whether the score is a forced mate rather than an evaluation.
  bool get isMate => isMateScore(score);

  @override
  String toString() => '${move.uci} ($score at depth $depth, $nodes nodes)';
}

/// The computer player.
///
/// Negamax with alpha-beta, iterative deepening and a quiescence search — the
/// oldest and least surprising arrangement there is, which is the point. It
/// has no opening book, no endgame tables and no learning. It looks at the
/// position in front of it and picks a move.
///
/// Deterministic: the same position, level and seed always produce the same
/// move. That is what makes a game reproducible when someone says the computer
/// played something strange, and it is why the randomness at the easy levels
/// is drawn from a seed rather than from the clock.
final class ChessBot {
  /// A player at [level], whose choices among near-equal moves are fixed by
  /// [seed].
  ChessBot({required this.level, this.seed = 0});

  /// How hard it plays.
  final BotLevel level;

  /// Fixes the choice between moves it rates equally.
  final int seed;

  int _nodes = 0;
  bool _outOfBudget = false;

  /// The move to play in [position], or `null` when there is none — the game
  /// is already over.
  ///
  /// [history] is the repetition keys of the positions the game has already
  /// been in. A move that returns to one of them is scored as the draw it
  /// would be, which is what stops a winning computer from shuffling and lets
  /// a losing one reach for the repetition on purpose.
  SearchResult? think(Position position, {Set<String> history = const <String>{}}) {
    final moves = _ordered(position.legalMoves);
    if (moves.isEmpty) return null;
    _nodes = 0;
    _outOfBudget = false;

    // Iterative deepening: each pass is cheap compared to the next, and it
    // means the budget can run out at any moment and still leave a complete
    // answer from the depth before.
    var best = <_Scored>[
      for (final move in moves) _Scored(move, 0),
    ];
    var completed = 0;
    for (var depth = 1; depth <= level.maxDepth; depth++) {
      final scored = <_Scored>[];
      var alpha = -kMateScore * 2;
      for (final entry in best) {
        final after = position.makeMove(entry.move);
        final score = history.contains(after.repetitionKey)
            ? 0
            : -_negamax(after, depth - 1, -kMateScore * 2, -alpha, 1);
        if (_outOfBudget) break;
        scored.add(_Scored(entry.move, score));
        // The window is only narrowed for the ordering of the next pass, not
        // for the scores themselves: a root move that is worse than one
        // already searched still needs a real score, because the easy levels
        // choose among the near-misses rather than always taking the best.
        alpha = max(alpha, score - level.slack - 1);
      }
      if (_outOfBudget) break;
      scored.sort((a, b) => b.score.compareTo(a.score));
      best = scored;
      completed = depth;
      // A forced mate is not going to be improved on by looking further.
      if (isMateScore(best.first.score)) break;
    }

    final chosen = _choose(best);
    return SearchResult(
      move: chosen.move,
      score: chosen.score,
      depth: completed,
      nodes: _nodes,
    );
  }

  /// Picks from the scored root moves.
  ///
  /// At the top level this is "take the best". Lower down it is "take
  /// something that is not much worse", which is what a mistake looks like
  /// from the inside: not a random move, but a plausible one that happens to
  /// drop a pawn.
  _Scored _choose(List<_Scored> scored) {
    final best = scored.first.score;
    final allowed = scored
        .where((_Scored entry) => best - entry.score <= level.slack)
        .toList();
    if (allowed.length == 1) return allowed.first;
    // Seeded by the position as well as by the bot, so that the same game
    // replays identically while two different positions do not both get the
    // first move in the list.
    final random = Random(seed ^ scored.length ^ (best * 31));
    return allowed[random.nextInt(allowed.length)];
  }

  /// The score of [position] for the side to move, looking [depth] further.
  int _negamax(Position position, int depth, int alpha, int beta, int ply) {
    if (_nodes >= level.maxNodes) {
      _outOfBudget = true;
      return 0;
    }
    _nodes++;

    // The fifty-move rule is checked here and repetition is not: the clock is
    // a number the position already carries, and repetition would need the
    // whole game's history threaded through every node to answer. The root
    // handles that case, which is the one that shows in play.
    if (position.halfmoveClock >= fiftyMoveLimit) return 0;

    if (depth <= 0) return _quiesce(position, alpha, beta, ply);

    // Moves are proved legal as they are played rather than before any of
    // them are: alpha-beta walks away from most of the list, and proving a
    // move legal means playing it. Whether there were any at all is what
    // distinguishes mate from stalemate, so it is counted on the way.
    var legal = 0;
    for (final move in _ordered(position.pseudoLegalMoves)) {
      final child = position.tryMove(move);
      if (child == null) continue;
      legal++;
      final score = -_negamax(child, depth - 1, -beta, -alpha, ply + 1);
      if (_outOfBudget) return alpha;
      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    if (legal == 0) return position.inCheck ? -mateIn(ply) : 0;
    return alpha;
  }

  /// Plays out the captures before evaluating.
  ///
  /// Without this the search stops in the middle of an exchange and evaluates
  /// a position where the queen has just been taken and the recapture is one
  /// ply out of sight. That is not a weak opponent, it is a broken one: it
  /// gives pieces away and cannot be talked out of it.
  int _quiesce(Position position, int alpha, int beta, int ply) {
    if (_nodes >= level.maxNodes) {
      _outOfBudget = true;
      return 0;
    }
    _nodes++;

    // Being in check is not a position to stand still in, so every legal move
    // is tried rather than only the captures. The ply cap is what stops a
    // series of checks from running away with the search.
    if (position.inCheck && ply < _quiescenceLimit) {
      var legal = 0;
      for (final move in _ordered(position.pseudoLegalMoves)) {
        final child = position.tryMove(move);
        if (child == null) continue;
        legal++;
        final score = -_quiesce(child, -beta, -alpha, ply + 1);
        if (_outOfBudget) return alpha;
        if (score >= beta) return beta;
        if (score > alpha) alpha = score;
      }
      return legal == 0 ? -mateIn(ply) : alpha;
    }

    // Standing pat: the side to move is not obliged to capture, so the static
    // score is a floor under everything below.
    final standing = evaluate(position);
    if (standing >= beta) return beta;
    if (standing > alpha) alpha = standing;
    if (ply >= _quiescenceLimit) return alpha;

    for (final move in _ordered(position.pseudoLegalMoves)) {
      if (!move.isCapture && move.promotion == null) continue;
      final child = position.tryMove(move);
      if (child == null) continue;
      final score = -_quiesce(child, -beta, -alpha, ply + 1);
      if (_outOfBudget) return alpha;
      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  /// How deep the captures may go on being played out.
  static const int _quiescenceLimit = 24;

  /// [moves] sorted so the ones most likely to be good come first.
  ///
  /// Alpha-beta only prunes what it has already found something better than,
  /// so the order moves are tried in is not a detail — it is most of the
  /// difference between looking at a hundred thousand positions and a million.
  /// Captures first, biggest victim to smallest attacker, then promotions,
  /// then the rest.
  List<Move> _ordered(List<Move> moves) =>
      moves.toList()..sort((Move a, Move b) => _priority(b) - _priority(a));

  int _priority(Move move) {
    var score = 0;
    if (move.captured != null) {
      // Most valuable victim, least valuable attacker: taking a queen with a
      // pawn is the move worth looking at first, whatever else is going on.
      score += 1000 + kPieceValue[move.captured]! - kPieceValue[move.moved]! ~/ 10;
    }
    if (move.promotion != null) score += 900;
    if (move.kind.isCastle) score += 60;
    return score;
  }
}

/// A root move and what the search made of it.
final class _Scored {
  const _Scored(this.move, this.score);

  final Move move;
  final int score;
}
