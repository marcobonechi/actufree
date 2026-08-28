import 'dart:async';
import 'dart:math';

import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:flutter/material.dart';
import 'package:puzzle_kit/puzzle_kit.dart';

import 'block_game.dart';
import 'board_view.dart';
import 'hand_tray.dart';

/// The slot a game in progress is kept in.
///
/// One slot, unlike Sudoku's slot per difficulty: there is only ever one Block
/// Blast run, and starting another is what ends the last one.
const String kBlockSlot = 'current';

/// Opens Block Blast, resuming the run in progress if there is one.
///
/// Doing the load here rather than inside the screen keeps the screen
/// synchronous — it is handed a game and draws it — and spares the player a
/// spinner on the way in.
Future<void> openBlockBlast(
  BuildContext context, {
  required GameStore store,
  required BestScores scores,
}) async {
  final saved =
      await store.load('blockblast', BlockGame.fromJson, slot: kBlockSlot);
  final best = await scores.best('blockblast');
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => BlockBlastScreen(
        initial: saved ?? BlockGame.newGame(Random().nextInt(1 << 31)),
        store: store,
        scores: scores,
        best: best,
      ),
    ),
  );
}

/// The playing screen.
class BlockBlastScreen extends StatefulWidget {
  /// Plays [initial].
  const BlockBlastScreen({
    required this.initial,
    this.store,
    this.scores,
    this.best = 0,
    super.key,
  });

  /// The game to play, new or resumed.
  final BlockGame initial;

  /// Where the game in progress is kept. Omitted in tests.
  final GameStore? store;

  /// Where the best score is kept. Omitted in tests.
  final BestScores? scores;

  /// The best score at the time the screen opened.
  final int best;

  @override
  State<BlockBlastScreen> createState() => _BlockBlastScreenState();
}

class _BlockBlastScreenState extends State<BlockBlastScreen> {
  late final BlockBlastGame _game = BlockBlastGame(widget.initial)
    ..addListener(_onGameChanged);
  final GlobalKey _boardKey = GlobalKey();
  final Random _seeds = Random();

  /// How far the carried piece is from the square it has snapped to.
  ///
  /// Kept here rather than on the game: it is a fact about where the board
  /// happens to be laid out on this screen, which is nothing the game should
  /// have an opinion about.
  final ValueNotifier<Offset> _carryCorrection =
      ValueNotifier<Offset>(Offset.zero);
  late int _best = widget.best;
  bool _announcedEnd = false;

  @override
  void initState() {
    super.initState();
    // A resumed game can already be over — the player may have closed the app
    // on the losing board rather than tapping through the dialog.
    if (_game.isOver) _endGame();
  }

  @override
  void dispose() {
    _game
      ..removeListener(_onGameChanged)
      ..dispose();
    _carryCorrection.dispose();
    super.dispose();
  }

  void _onGameChanged() {
    unawaited(_persist());
    if (!_game.isOver || _announcedEnd) return;
    // The board finishes mid-build, so the dialog waits for the frame that
    // shows the final piece landing before covering it up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _endGame();
    });
  }

  /// Writes the run to its slot, or clears the slot once it is over — a
  /// finished game is not something to resume into.
  Future<void> _persist() async {
    final store = widget.store;
    if (store == null) return;
    if (_game.isOver) {
      await store.clear('blockblast', slot: kBlockSlot);
      return;
    }
    await store.save(_game.state, slot: kBlockSlot);
  }

  Future<void> _endGame() async {
    if (_announcedEnd) return;
    _announcedEnd = true;
    final score = _game.score;
    final beaten = await widget.scores?.record('blockblast', score) ?? false;
    if (!mounted) return;
    setState(() {
      if (beaten) _best = score;
    });
    await _showGameOver(score: score, beaten: beaten);
  }

  Future<void> _showGameOver({
    required int score,
    required bool beaten,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        key: const ValueKey<String>('game-over'),
        title: const Text('No moves left'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('$score points.'),
            const SizedBox(height: 4),
            Text(
              beaten ? 'A new best.' : 'Your best is $_best.',
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
    _game.restart(_seeds.nextInt(1 << 31));
  }

  Future<void> _confirmRestart() async {
    if (_game.state.board.isEmpty && _game.score == 0) return;
    final start = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Start again?'),
        content: Text(
          'This run is on ${_game.score} points and will be lost.',
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

  /// Follows the carried piece to [globalTopLeft], the top-left corner the
  /// pointer has it at.
  void _carryTo(Offset globalTopLeft) {
    _game.updateDrag(_anchorFor(globalTopLeft));
    _carryCorrection.value = _correctionFor(globalTopLeft);
  }

  /// How far the snapped square is from where the pointer has the piece.
  ///
  /// [Offset.zero] when the piece has not snapped anywhere, which leaves it
  /// following the pointer exactly — it is not going to land, so it should not
  /// pretend to be lining up.
  Offset _correctionFor(Offset globalTopLeft) {
    final settled = _game.anchor;
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (settled == null || box == null || !box.hasSize) return Offset.zero;
    final cell = box.size.width / boardSize;
    final target = box.localToGlobal(
      Offset(settled.col * cell, settled.row * cell),
    );
    return target - globalTopLeft;
  }

  /// The board square that [globalTopLeft] — the top-left corner of the piece
  /// being carried — is nearest to, or `null` when the board is not laid out.
  ///
  /// Rounds rather than truncates, so a piece nudged a little past a boundary
  /// snaps to the square it is mostly over. Coordinates off the board come
  /// back as they are; the engine refuses them, which is the same answer.
  Coord? _anchorFor(Offset globalTopLeft) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.width == 0) return null;
    final local = box.globalToLocal(globalTopLeft);
    final cell = box.size.width / boardSize;
    return Coord((local.dy / cell).round(), (local.dx / cell).round());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Block Blast'),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('restart'),
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Start again',
            onPressed: _confirmRestart,
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _game,
          builder: (BuildContext context, _) => LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final board = _boardSide(constraints);
              return DragTarget<int>(
                onWillAcceptWithDetails: (_) => true,
                onMove: (DragTargetDetails<int> details) =>
                    _carryTo(details.offset),
                onLeave: (_) {
                  _game.updateDrag(null);
                  _carryCorrection.value = Offset.zero;
                },
                onAcceptWithDetails: (DragTargetDetails<int> details) {
                  _carryTo(details.offset);
                  _game.drop();
                  _carryCorrection.value = Offset.zero;
                },
                builder: (BuildContext context, _, _) => Column(
                  children: <Widget>[
                    _Header(game: _game, best: _best),
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: board,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Semantics(
                                label: 'Board',
                                value: '${_game.state.board.filledCount} of '
                                    '$cellCount squares filled',
                                child: SizedBox(
                                  key: _boardKey,
                                  width: board,
                                  height: board,
                                  child: BlockBoardView(game: _game),
                                ),
                              ),
                              SizedBox(height: board * 0.05),
                              HandTray(
                                game: _game,
                                boardCellSize: board / boardSize,
                                carryCorrection: _carryCorrection,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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
  /// The tray is five half-cells tall, so board and tray together want
  /// `1 + 5/16` of the board's own width in height. Solving for the width that
  /// fits keeps the whole thing on screen on a short phone in landscape rather
  /// than overflowing the column.
  static double _boardSide(BoxConstraints constraints) {
    const double trayShare = 5 / 16;
    const double padding = 24;
    const double headerHeight = 76;
    final fromWidth = constraints.maxWidth - padding;
    final fromHeight = (constraints.maxHeight - headerHeight - padding) /
        (1 + trayShare + 0.05);
    return max(80, min(min(fromWidth, fromHeight), 520));
  }
}

/// The score, the best so far, and what the last clear was worth.
class _Header extends StatelessWidget {
  const _Header({required this.game, required this.best});

  final BlockBlastGame game;
  final int best;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The flash is stacked rather than placed beside the score: as a sibling
    // in a row it would take its width whether or not anything was showing,
    // and the score would sit permanently off-centre.
    return SizedBox(
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '${game.score}',
                key: const ValueKey<String>('score'),
                style: theme.textTheme.displaySmall,
              ),
              Text(
                best > 0 ? 'Best $best' : 'No best yet',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Positioned(right: 24, child: _ClearFlash(game: game)),
        ],
      ),
    );
  }
}

/// A note of what the last clear was worth, fading out after it.
///
/// Only shown for a clear. A placement that scores its four cells and nothing
/// else is not news, and a number appearing on every single move would stop
/// meaning anything.
class _ClearFlash extends StatefulWidget {
  const _ClearFlash({required this.game});

  final BlockBlastGame game;

  @override
  State<_ClearFlash> createState() => _ClearFlashState();
}

class _ClearFlashState extends State<_ClearFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late int _seenTick = widget.game.clearTick;

  static const Map<int, String> _names = <int, String>{
    2: 'Double',
    3: 'Triple',
    4: 'Quadruple',
  };

  @override
  void didUpdateWidget(covariant _ClearFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tick = widget.game.clearTick;
    if (tick == _seenTick) return;
    _seenTick = tick;
    _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = widget.game.lastLines;
    return SizedBox(
      width: 110,
      child: AnimatedBuilder(
        animation: _fade,
        builder: (BuildContext context, _) {
          final t = _fade.value;
          if (t == 0 || t == 1) return const SizedBox.shrink();
          return Opacity(
            opacity: (1 - t).clamp(0, 1).toDouble(),
            child: Transform.translate(
              offset: Offset(0, -16 * t),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '+${widget.game.lastPoints}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_names[lines] != null)
                    Text(
                      _names[lines]!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
