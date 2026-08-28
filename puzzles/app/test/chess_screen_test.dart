import 'package:chess_engine/chess_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_kit/puzzle_kit.dart';
import 'package:puzzles_app/chess/board_view.dart';
import 'package:puzzles_app/chess/bot_runner.dart';
import 'package:puzzles_app/chess/chess_screen.dart';
import 'package:puzzles_app/theme.dart';

import 'chess_match_test.dart' show HeldMove, firstLegalMove;

void main() {
  Widget host(
    ChessGame game, {
    GameStore? store,
    Opponent opponent = const Opponent.twoPlayers(),
    MoveChooser chooser = firstLegalMove,
  }) =>
      MaterialApp(
        theme: actufreeTheme(Brightness.light),
        home: ChessScreen(
          initial: game,
          store: store,
          opponent: opponent,
          chooser: chooser,
        ),
      );

  ChessGame gameOn(String fen) =>
      ChessGame.fromPosition(Position.fromFen(fen));

  /// Taps the square named [name], allowing for the board being turned round.
  Future<void> tapSquare(
    WidgetTester tester,
    String name, {
    bool flipped = false,
  }) async {
    final board = tester.getRect(find.byType(ChessBoardView));
    final cell = board.width / boardSize;
    final square = Square.parse(name);
    final row = flipped ? boardSize - 1 - square.row : square.row;
    final col = flipped ? boardSize - 1 - square.col : square.col;
    await tester.tapAt(
      board.topLeft + Offset((col + 0.5) * cell, (row + 0.5) * cell),
    );
    await tester.pumpAndSettle();
  }

  /// Plays a line given as pairs of squares.
  Future<void> playLine(WidgetTester tester, List<String> squares) async {
    for (final square in squares) {
      await tapSquare(tester, square);
    }
  }

  String statusOf(WidgetTester tester, PieceColor color) =>
      tester.widget<Text>(find.byKey(ValueKey<String>('status-${color.name}')))
          .data!;

  testWidgets('shows a board and a bar for each player', (tester) async {
    await tester.pumpWidget(host(ChessGame.newGame()));

    expect(find.byType(ChessBoardView), findsOneWidget);
    expect(find.text('White'), findsOneWidget);
    expect(find.text('Black'), findsOneWidget);
    expect(statusOf(tester, PieceColor.white), 'To move');
    expect(statusOf(tester, PieceColor.black), 'Waiting');
  });

  testWidgets('a tap on a piece and a tap on a square plays the move', (
    tester,
  ) async {
    await tester.pumpWidget(host(ChessGame.newGame()));
    await playLine(tester, <String>['e2', 'e4']);

    expect(statusOf(tester, PieceColor.white), 'Waiting');
    expect(statusOf(tester, PieceColor.black), 'To move');
  });

  testWidgets('a tap on an illegal square leaves the board alone', (
    tester,
  ) async {
    await tester.pumpWidget(host(ChessGame.newGame()));
    await playLine(tester, <String>['e2', 'e5']);

    expect(statusOf(tester, PieceColor.white), 'To move');
  });

  testWidgets('says when a king is in check', (tester) async {
    await tester.pumpWidget(host(gameOn('4k3/8/8/8/8/8/8/R3K3 w - - 0 1')));
    await playLine(tester, <String>['a1', 'a8']);

    expect(statusOf(tester, PieceColor.black), 'In check');
  });

  testWidgets('asks what a pawn becomes, and promotes to it', (tester) async {
    // The black rook is there so the game does not end in a draw the moment
    // a lone knight appears on the board.
    await tester.pumpWidget(host(gameOn('4k3/1P6/8/8/8/8/7r/4K3 w - - 0 1')));
    await playLine(tester, <String>['b7', 'b8']);

    expect(find.byKey(const ValueKey<String>('promotion')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('promote-knight')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('promotion')), findsNothing);
    expect(statusOf(tester, PieceColor.black), 'To move');
  });

  testWidgets('announces a checkmate and offers another game', (tester) async {
    await tester.pumpWidget(host(ChessGame.newGame()));
    // The fool's mate: 1. f3 e5 2. g4 Qh4#.
    await playLine(
      tester,
      <String>['f2', 'f3', 'e7', 'e5', 'g2', 'g4', 'd8', 'h4'],
    );

    expect(find.byKey(const ValueKey<String>('game-over')), findsOneWidget);
    expect(find.text('Checkmate'), findsOneWidget);
    expect(find.text('Black wins.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('play-again')));
    await tester.pumpAndSettle();
    expect(statusOf(tester, PieceColor.white), 'To move');
    expect(find.byKey(const ValueKey<String>('game-over')), findsNothing);
  });

  testWidgets('lets a mated player take the move back', (tester) async {
    await tester.pumpWidget(host(ChessGame.newGame()));
    await playLine(
      tester,
      <String>['f2', 'f3', 'e7', 'e5', 'g2', 'g4', 'd8', 'h4'],
    );
    await tester.tap(find.byKey(const ValueKey<String>('take-back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('game-over')), findsNothing);
    expect(statusOf(tester, PieceColor.black), 'To move');
  });

  testWidgets('takes the last move back', (tester) async {
    await tester.pumpWidget(host(ChessGame.newGame()));
    await playLine(tester, <String>['e2', 'e4']);
    await tester.tap(find.byKey(const ValueKey<String>('undo')));
    await tester.pumpAndSettle();

    expect(statusOf(tester, PieceColor.white), 'To move');
  });

  testWidgets('turns the board around, players and all', (tester) async {
    await tester.pumpWidget(host(ChessGame.newGame()));
    final whiteFirst =
        tester.getCenter(find.byKey(const ValueKey<String>('player-white')));
    final blackFirst =
        tester.getCenter(find.byKey(const ValueKey<String>('player-black')));
    expect(whiteFirst.dy, greaterThan(blackFirst.dy),
        reason: 'White starts at the bottom');

    await tester.tap(find.byKey(const ValueKey<String>('flip')));
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(find.byKey(const ValueKey<String>('player-white'))).dy,
      lessThan(
        tester.getCenter(find.byKey(const ValueKey<String>('player-black'))).dy,
      ),
    );

    // And the squares have moved with it: e2 is now where e7 was.
    await tapSquare(tester, 'e7', flipped: true);
    await tapSquare(tester, 'e5', flipped: true);
    expect(statusOf(tester, PieceColor.white), 'To move',
        reason: 'Black moved, so it is White again');
  });

  testWidgets('counts the material one side is up', (tester) async {
    await tester.pumpWidget(host(ChessGame.newGame()));
    await playLine(
      tester,
      <String>['e2', 'e4', 'd7', 'd5', 'e4', 'd5'],
    );

    expect(find.byKey(const ValueKey<String>('lead-white')), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('lead-black')), findsNothing);
  });

  group('with a store', () {
    testWidgets('keeps the game as it is played, and drops it when it ends', (
      tester,
    ) async {
      final store = GameStore(MemoryStore());
      await tester.pumpWidget(host(ChessGame.newGame(), store: store));

      await playLine(tester, <String>['f2', 'f3', 'e7', 'e5']);
      final saved =
          await store.load('chess', ChessSave.fromJson, slot: kChessSlot);
      expect(saved, isNotNull);
      expect(saved!.game.notation, <String>['f3', 'e5']);
      expect(saved.opponent, const Opponent.twoPlayers());

      await playLine(tester, <String>['g2', 'g4', 'd8', 'h4']);
      expect(await store.has('chess', slot: kChessSlot), isFalse,
          reason: 'a finished game is not something to resume into');
    });

    testWidgets('picks a resumed game up where it was left', (tester) async {
      final store = GameStore(MemoryStore());
      final part = ChessGame.newGame().playFrom(
        Square.parse('e2'),
        Square.parse('e4'),
      )!;
      await store.save(ChessSave(game: part), slot: kChessSlot);
      await tester.pumpWidget(host(part, store: store));

      expect(statusOf(tester, PieceColor.black), 'To move');
      await playLine(tester, <String>['e7', 'e5']);
      expect(statusOf(tester, PieceColor.white), 'To move');
    });

    testWidgets('shows the dialog again for a game that ended off screen', (
      tester,
    ) async {
      // Shutting the app on the mating move rather than tapping through the
      // dialog should not leave the players wondering.
      await tester.pumpWidget(
        host(
          gameOn('rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('game-over')), findsOneWidget);
    });
  });

  group('against the computer', () {
    const opponent = Opponent.computer(
      level: BotLevel.easy,
      plays: PieceColor.black,
    );

    testWidgets('says it is thinking, then plays', (tester) async {
      final held = HeldMove();
      await tester.pumpWidget(
        host(ChessGame.newGame(), opponent: opponent, chooser: held.choose),
      );
      await playLine(tester, <String>['e2', 'e4']);

      expect(statusOf(tester, PieceColor.black), 'Thinking…');
      held.answer();
      await tester.pumpAndSettle();
      expect(statusOf(tester, PieceColor.black), 'Easy');
      expect(statusOf(tester, PieceColor.white), 'To move');
    });

    testWidgets('undo takes back your move and its reply', (tester) async {
      await tester.pumpWidget(host(ChessGame.newGame(), opponent: opponent));
      await playLine(tester, <String>['e2', 'e4']);
      await tester.tap(find.byKey(const ValueKey<String>('undo')));
      await tester.pumpAndSettle();

      expect(statusOf(tester, PieceColor.white), 'To move');
      // Back to the starting position, so e2 is a pawn to be picked up again.
      await playLine(tester, <String>['e2', 'e4']);
      expect(statusOf(tester, PieceColor.white), 'To move');
    });

    testWidgets('keeps the opponent in the save', (tester) async {
      final store = GameStore(MemoryStore());
      await tester.pumpWidget(
        host(ChessGame.newGame(), store: store, opponent: opponent),
      );
      await playLine(tester, <String>['e2', 'e4']);

      final saved =
          await store.load('chess', ChessSave.fromJson, slot: kChessSlot);
      expect(saved!.opponent, opponent);
    });
  });
}
