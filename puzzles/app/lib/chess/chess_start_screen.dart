import 'dart:async';

import 'package:chess_engine/chess_engine.dart';
import 'package:flutter/material.dart';
import 'package:puzzle_kit/puzzle_kit.dart';

import 'bot_runner.dart';
import 'chess_screen.dart';

/// Opens chess at the choice of who is playing.
Future<void> openChess(BuildContext context, {required GameStore store}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ChessStartScreen(store: store),
      ),
    );

/// Who is playing, and the way back into a game already going.
///
/// The choice is made here rather than as a switch on the board, so that the
/// board never has to ask what kind of game it is in the middle of one — and
/// so that turning the computer on cannot happen by accident halfway through
/// a game against someone sitting opposite.
class ChessStartScreen extends StatefulWidget {
  /// Creates the screen.
  const ChessStartScreen({
    required this.store,
    this.chooser = chooseMoveOffThread,
    super.key,
  });

  /// Where the game in progress is kept.
  final GameStore store;

  /// How the computer's move is worked out, handed to the game this screen
  /// starts. Replaced in tests.
  final MoveChooser chooser;

  @override
  State<ChessStartScreen> createState() => _ChessStartScreenState();
}

class _ChessStartScreenState extends State<ChessStartScreen> {
  ChessSave? _saved;
  bool _loaded = false;
  PieceColor _side = PieceColor.white;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final saved =
        await widget.store.load('chess', ChessSave.fromJson, slot: kChessSlot);
    if (mounted) {
      setState(() {
        _saved = saved;
        _loaded = true;
      });
    }
  }

  /// Opens [save], or starts a new game against [opponent].
  ///
  /// Starting a new one throws away the game in progress, since there is only
  /// one board — so it asks first, the same way the board itself does.
  Future<void> _open({ChessSave? save, Opponent? opponent}) async {
    if (save == null && _saved != null && !await _confirmDiscard()) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ChessScreen(
          initial: save?.game ?? ChessGame.newGame(),
          opponent: save?.opponent ?? opponent ?? const Opponent.twoPlayers(),
          store: widget.store,
          chooser: widget.chooser,
        ),
      ),
    );
    await _refresh();
  }

  Future<bool> _confirmDiscard() async {
    final start = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        key: const ValueKey<String>('discard-game'),
        title: const Text('Start a new game?'),
        content: Text(
          'The game in progress — ${_describe(_saved!)} — will be lost.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('New game'),
          ),
        ],
      ),
    );
    return start ?? false;
  }

  /// A line describing the game waiting to be resumed.
  static String _describe(ChessSave save) {
    final moves = save.game.moves.length;
    final turn = '${save.game.sideToMove.label} to move';
    return '${save.opponent.label} · $turn · '
        '${moves == 1 ? '1 move' : '$moves moves'} in';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Chess')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                if (_saved != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _Choice(
                      id: 'resume',
                      title: 'Continue',
                      blurb: _describe(_saved!),
                      filled: true,
                      onPressed: () => _open(save: _saved),
                    ),
                  ),
                Text('Two players', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                _Choice(
                  id: 'two-players',
                  title: 'On one board',
                  blurb: 'Take turns on this screen',
                  enabled: _loaded,
                  onPressed: () =>
                      _open(opponent: const Opponent.twoPlayers()),
                ),
                const SizedBox(height: 24),
                Text('Play the computer', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                // Which colour you take is a property of the game about to
                // start, not of the level, so it is asked once above all
                // three rather than doubling them.
                SegmentedButton<PieceColor>(
                  segments: <ButtonSegment<PieceColor>>[
                    for (final color in PieceColor.values)
                      ButtonSegment<PieceColor>(
                        value: color,
                        label: Text('You play ${color.label}'),
                      ),
                  ],
                  selected: <PieceColor>{_side},
                  showSelectedIcon: false,
                  onSelectionChanged: (Set<PieceColor> chosen) =>
                      setState(() => _side = chosen.single),
                ),
                const SizedBox(height: 8),
                for (final level in BotLevel.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _Choice(
                      id: 'level-${level.name}',
                      title: level.label,
                      blurb: level.blurb,
                      enabled: _loaded,
                      onPressed: () => _open(
                        opponent: Opponent.computer(
                          level: level,
                          plays: _side.opponent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One thing the player can start.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.id,
    required this.title,
    required this.blurb,
    required this.onPressed,
    this.filled = false,
    this.enabled = true,
  });

  final String id;
  final String title;
  final String blurb;
  final VoidCallback onPressed;
  final bool filled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The text colour comes from the button rather than from the text theme:
    // a title styled straight out of `titleMedium` carries the colour for
    // text on a surface, which on a filled button is dark on dark.
    final ink = filled
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSecondaryContainer;
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(color: ink),
          ),
          Text(
            blurb,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: ink.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
    final key = ValueKey<String>('chess-$id');
    return SizedBox(
      width: double.infinity,
      child: filled
          ? FilledButton(
              key: key,
              onPressed: enabled ? onPressed : null,
              child: child,
            )
          : FilledButton.tonal(
              key: key,
              onPressed: enabled ? onPressed : null,
              child: child,
            ),
    );
  }
}
