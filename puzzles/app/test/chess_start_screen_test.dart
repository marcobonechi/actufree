import 'package:chess_engine/chess_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_kit/puzzle_kit.dart';
import 'package:puzzles_app/chess/board_view.dart';
import 'package:puzzles_app/chess/chess_screen.dart';
import 'package:puzzles_app/chess/chess_start_screen.dart';
import 'package:puzzles_app/theme.dart';

import 'chess_match_test.dart' show firstLegalMove;

void main() {
  Widget host(GameStore store) => MaterialApp(
        theme: actufreeTheme(Brightness.light),
        home: ChessStartScreen(store: store, chooser: firstLegalMove),
      );

  Finder choice(String id) => find.byKey(ValueKey<String>('chess-$id'));

  String statusOf(WidgetTester tester, PieceColor color) =>
      tester.widget<Text>(find.byKey(ValueKey<String>('status-${color.name}')))
          .data!;

  testWidgets('offers two players and the three levels', (tester) async {
    await tester.pumpWidget(host(GameStore(MemoryStore())));
    await tester.pumpAndSettle();

    expect(choice('two-players'), findsOneWidget);
    for (final level in BotLevel.values) {
      expect(choice('level-${level.name}'), findsOneWidget);
      expect(find.text(level.blurb), findsOneWidget);
    }
    expect(choice('resume'), findsNothing, reason: 'nothing to continue');
  });

  testWidgets('starts a game between two people', (tester) async {
    await tester.pumpWidget(host(GameStore(MemoryStore())));
    await tester.pumpAndSettle();
    await tester.tap(choice('two-players'));
    await tester.pumpAndSettle();

    expect(find.byType(ChessBoardView), findsOneWidget);
    expect(statusOf(tester, PieceColor.white), 'To move');
    expect(statusOf(tester, PieceColor.black), 'Waiting');
  });

  testWidgets('starts a game against the computer, which plays Black', (
    tester,
  ) async {
    await tester.pumpWidget(host(GameStore(MemoryStore())));
    await tester.pumpAndSettle();
    await tester.tap(choice('level-medium'));
    await tester.pumpAndSettle();

    expect(statusOf(tester, PieceColor.white), 'To move');
    expect(statusOf(tester, PieceColor.black), 'Medium',
        reason: "the computer's side says which level it is");
  });

  testWidgets('hands the computer White when you choose to play Black', (
    tester,
  ) async {
    await tester.pumpWidget(host(GameStore(MemoryStore())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('You play Black'));
    await tester.pumpAndSettle();
    await tester.tap(choice('level-easy'));
    await tester.pumpAndSettle();

    // The stand-in computer moves at once, so by now it has.
    expect(statusOf(tester, PieceColor.white), 'Easy');
    expect(statusOf(tester, PieceColor.black), 'To move');

    // And the board is drawn from the side the player is on.
    final board = tester.getRect(find.byType(ChessBoardView));
    final black =
        tester.getCenter(find.byKey(const ValueKey<String>('player-black')));
    expect(black.dy, greaterThan(board.center.dy),
        reason: 'the player sits at the bottom of their own board');
  });

  group('with a game in progress', () {
    Future<GameStore> storeWith(Opponent opponent) async {
      final store = GameStore(MemoryStore());
      final game = ChessGame.newGame()
          .playFrom(Square.parse('e2'), Square.parse('e4'))!;
      await store.save(
        ChessSave(game: game, opponent: opponent),
        slot: kChessSlot,
      );
      return store;
    }

    testWidgets('offers to continue it, and says what it is', (tester) async {
      await tester.pumpWidget(host(await storeWith(const Opponent.computer(
        level: BotLevel.hard,
        plays: PieceColor.black,
      ))));
      await tester.pumpAndSettle();

      expect(choice('resume'), findsOneWidget);
      expect(
        find.text('Computer (Hard) · Black to move · 1 move in'),
        findsOneWidget,
      );
    });

    testWidgets('continues it against the same opponent', (tester) async {
      await tester.pumpWidget(host(await storeWith(const Opponent.computer(
        level: BotLevel.medium,
        plays: PieceColor.black,
      ))));
      await tester.pumpAndSettle();
      await tester.tap(choice('resume'));
      await tester.pumpAndSettle();

      // It was Black to move and Black is the computer, so it has replied.
      expect(statusOf(tester, PieceColor.white), 'To move');
      expect(statusOf(tester, PieceColor.black), 'Medium');
    });

    testWidgets('asks before throwing it away for a new one', (tester) async {
      await tester.pumpWidget(host(await storeWith(const Opponent.twoPlayers())));
      await tester.pumpAndSettle();
      await tester.tap(choice('two-players'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('discard-game')), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(find.byType(ChessBoardView), findsNothing);

      await tester.tap(choice('level-easy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New game'));
      await tester.pumpAndSettle();
      expect(find.byType(ChessBoardView), findsOneWidget);
      expect(statusOf(tester, PieceColor.black), 'Easy');
    });
  });
}
