import 'dart:async';
import 'dart:math';

import 'package:chess_engine/chess_engine.dart';
import 'package:flutter/material.dart';
import 'package:puzzle_kit/puzzle_kit.dart';

import '../theme.dart';
import 'board_view.dart';
import 'bot_runner.dart';
import 'chess_match.dart';
import 'piece_paint.dart';

/// The slot a game in progress is kept in.
///
/// One slot: there is one board, and setting the pieces up again is what ends
/// the game that was on it.
const String kChessSlot = 'current';

/// How tall the bar above and below the board is.
const double kPlayerBarHeight = 72;

/// The playing screen: one board, and either two people or one and the
/// computer.
class ChessScreen extends StatefulWidget {
  /// Plays [initial] against [opponent].
  const ChessScreen({
    required this.initial,
    this.opponent = const Opponent.twoPlayers(),
    this.store,
    this.chooser = chooseMoveOffThread,
    super.key,
  });

  /// The game to play, new or resumed.
  final ChessGame initial;

  /// Who is playing the other side.
  final Opponent opponent;

  /// Where the game in progress is kept. Omitted in tests.
  final GameStore? store;

  /// How the computer's move is worked out. Replaced in tests.
  final MoveChooser chooser;

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  late final ChessMatch _match = ChessMatch(
    widget.initial,
    opponent: widget.opponent,
    chooser: widget.chooser,
  )..addListener(_onMatchChanged);
  bool _announcedEnd = false;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    // Against the computer the board is drawn from the side the person is
    // playing. Against another person it starts the way a board starts, and
    // the flip button is there for turning it round.
    if (widget.opponent.human == PieceColor.black) _match.flip();
    // A resumed game can already be finished — the players may have shut the
    // app on the mating move rather than tapping through the dialog.
    if (_match.isOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _endGame());
    }
  }

  @override
  void dispose() {
    _match
      ..removeListener(_onMatchChanged)
      ..dispose();
    super.dispose();
  }

  void _onMatchChanged() {
    unawaited(_persist());
    if (_match.promoting != null && !_asking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_askPromotion());
      });
      return;
    }
    if (!_match.isOver || _announcedEnd) return;
    // The mating move lands mid-build; the dialog waits for the frame that
    // shows it before covering the board up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_endGame());
    });
  }

  /// Writes the game to its slot, or clears the slot once it is over — a
  /// finished game is not something to resume into.
  Future<void> _persist() async {
    final store = widget.store;
    if (store == null) return;
    if (_match.isOver) {
      await store.clear('chess', slot: kChessSlot);
      return;
    }
    await store.save(
      ChessSave(game: _match.game, opponent: widget.opponent),
      slot: kChessSlot,
    );
  }

  Future<void> _askPromotion() async {
    if (_asking) return;
    _asking = true;
    final palette = chessPaletteOf(context);
    final color = _match.sideToMove;
    final kind = await showDialog<PieceKind>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        key: const ValueKey<String>('promotion'),
        title: const Text('Promote to'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final kind in PieceKind.promotions)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: IconButton(
                  key: ValueKey<String>('promote-${kind.name}'),
                  tooltip: kind.name,
                  iconSize: 48,
                  onPressed: () => Navigator.of(context).pop(kind),
                  icon: PieceGlyph(
                    piece: ChessPiece(color, kind),
                    body: palette.body(color),
                    outline: palette.outline(color),
                    size: 44,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    _asking = false;
    if (!mounted) return;
    if (kind == null) {
      _match.cancelPromotion();
    } else {
      _match.promote(kind);
    }
  }

  /// Whether this ending is somebody's win worth throwing colour at.
  ///
  /// A draw is not, and losing to the computer certainly is not. Against
  /// another person on the same phone either result is somebody's win, and the
  /// two of them can work out whose.
  bool _worthCelebrating(Outcome outcome) {
    final winner = outcome.winner;
    if (winner == null) return false;
    final human = widget.opponent.human;
    return human == null || winner == human;
  }

  Future<void> _endGame() async {
    if (_announcedEnd || !_match.isOver) return;
    _announcedEnd = true;
    final outcome = _match.outcome!;
    if (_worthCelebrating(outcome)) {
      CelebrationScope.maybeOf(context)?.fountain(colors: kOkabeItoPieces);
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        key: const ValueKey<String>('game-over'),
        title: Text(outcome.ending.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              outcome.winner == null
                  ? 'Nobody wins this one.'
                  : '${outcome.winner!.label} wins.',
            ),
            const SizedBox(height: 4),
            Text(
              '${_match.game.moves.length} moves.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context)
                ..pop()
                ..pop();
            },
            child: const Text('Back to menu'),
          ),
          TextButton(
            key: const ValueKey<String>('take-back'),
            onPressed: () {
              Navigator.of(context).pop();
              _announcedEnd = false;
              _match.undo();
            },
            child: const Text('Take it back'),
          ),
          FilledButton(
            key: const ValueKey<String>('play-again'),
            onPressed: () {
              Navigator.of(context).pop();
              _restart();
            },
            child: const Text('Play again'),
          ),
        ],
      ),
    );
  }

  void _restart() {
    _announcedEnd = false;
    _match.restart();
  }

  Future<void> _confirmRestart() async {
    if (!_match.canUndo) return;
    final start = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Set the pieces up again?'),
        content: Text(
          'This game is ${_match.game.moves.length} moves in and will be '
          'lost.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start again'),
          ),
        ],
      ),
    );
    if (start ?? false) _restart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess'),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('flip'),
            icon: const Icon(Icons.swap_vert),
            tooltip: 'Turn the board around',
            onPressed: _match.flip,
          ),
          IconButton(
            key: const ValueKey<String>('undo'),
            icon: const Icon(Icons.undo),
            tooltip: widget.opponent.isComputer
                ? 'Take back your last move'
                : 'Take back the last move',
            onPressed: _match.undo,
          ),
          IconButton(
            key: const ValueKey<String>('restart'),
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Set the pieces up again',
            onPressed: _confirmRestart,
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _match,
          builder: (BuildContext context, _) => LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final side = _boardSide(constraints);
              // The player at the top of the screen is whoever is not at the
              // bottom, and who is at the bottom is what turning the board
              // around changes.
              final bottom =
                  _match.flipped ? PieceColor.black : PieceColor.white;
              return Center(
                child: SizedBox(
                  width: side,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _PlayerBar(match: _match, color: bottom.opponent),
                      SizedBox(
                        width: side,
                        height: side,
                        child: ChessBoardView(match: _match),
                      ),
                      _PlayerBar(match: _match, color: bottom),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// How wide the board can be.
  ///
  /// The two player bars are a fixed height, so the board takes whatever is
  /// left of the shorter side. Capped, because a board wider than a hand can
  /// reach across is worse on a tablet, not better.
  static double _boardSide(BoxConstraints constraints) {
    const double padding = 16;
    final fromWidth = constraints.maxWidth - padding;
    final fromHeight =
        constraints.maxHeight - kPlayerBarHeight * 2 - padding;
    return max(120, min(min(fromWidth, fromHeight), 560));
  }
}

/// One side's row: whose turn it is, what they have taken, and how far ahead
/// that leaves them.
///
/// The captured pieces are the other side's men, drawn in the other side's
/// colours — they are trophies, and a row of them in your own colour would
/// read as pieces you had somehow acquired.
class _PlayerBar extends StatelessWidget {
  const _PlayerBar({required this.match, required this.color});

  final ChessMatch match;
  final PieceColor color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = chessPaletteOf(context);
    final taken = match.game.capturedBy(color);
    final lead = match.game.materialLead(color);
    final isTurn = !match.isOver && match.sideToMove == color;
    final inCheck = isTurn && match.position.inCheck;
    final isComputer = match.opponent.controls(color);

    return SizedBox(
      height: kPlayerBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isTurn
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
                : Colors.transparent,
          ),
          child: Row(
            children: <Widget>[
              PieceGlyph(
                piece: ChessPiece(color, PieceKind.king),
                body: palette.body(color),
                outline: palette.outline(color),
                size: 30,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    color.label,
                    key: ValueKey<String>('player-${color.name}'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isTurn ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  Text(
                    _status(
                      match,
                      color,
                      isTurn: isTurn,
                      inCheck: inCheck,
                      isComputer: isComputer,
                    ),
                    key: ValueKey<String>('status-${color.name}'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: inCheck
                          ? palette.check
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight:
                          inCheck ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Flexible(
                child: _CapturedRow(
                  taken: taken,
                  color: color.opponent,
                  palette: palette,
                ),
              ),
              if (lead > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '+$lead',
                    key: ValueKey<String>('lead-${color.name}'),
                    style: tabularFigures(
                      theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The line under a player's name.
  ///
  /// The computer's side says who it is when there is nothing else to report,
  /// so the level a game was started at is visible for the whole of it rather
  /// than only on the screen that chose it.
  static String _status(
    ChessMatch match,
    PieceColor color, {
    required bool isTurn,
    required bool inCheck,
    required bool isComputer,
  }) {
    final outcome = match.outcome;
    if (outcome != null) {
      if (outcome.isDraw) return 'Drawn';
      return outcome.winner == color ? 'Won' : 'Lost';
    }
    if (isComputer && match.isThinking && isTurn) return 'Thinking…';
    if (inCheck) return 'In check';
    if (isComputer) return match.opponent.level!.label;
    return isTurn ? 'To move' : 'Waiting';
  }
}

/// The men one side has taken, smallest drawings the eye can still count.
class _CapturedRow extends StatelessWidget {
  const _CapturedRow({
    required this.taken,
    required this.color,
    required this.palette,
  });

  final List<PieceKind> taken;
  final PieceColor color;
  final ChessPalette palette;

  @override
  Widget build(BuildContext context) {
    if (taken.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          for (final kind in taken)
            // Overlapped a little, the way they would be piled at the side of
            // a real board: sixteen of them at full width would be wider than
            // the board they came off.
            Padding(
              padding: const EdgeInsets.only(right: 1),
              child: PieceGlyph(
                piece: ChessPiece(color, kind),
                body: palette.body(color),
                outline: palette.outline(color),
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}
