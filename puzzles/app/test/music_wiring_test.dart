import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_kit/puzzle_kit.dart';
import 'package:puzzles_app/sudoku/sudoku_screen.dart';
import 'package:puzzles_app/theme.dart';
import 'package:sudoku_engine/sudoku_engine.dart' as sudoku;

/// These tests run with no audio plugin behind them, which is the point twice
/// over: they check which track the app *asks* for, and they only pass at all
/// because a service that cannot play anything still does not throw.
void main() {
  final sudoku.SudokuPuzzle puzzle =
      const sudoku.SudokuGenerator(7).generate(sudoku.Difficulty.easy);

  Future<({MusicService music, Widget app})> app({
    List<GameEntry>? games,
  }) async {
    final SettingsController settings =
        await SettingsController.load(MemoryStore());
    final MusicService music = MusicService(
      settings: settings,
      menuAsset: 'assets/audio/menu_loop.m4a',
      matchAsset: 'assets/audio/match_loop.m4a',
    );
    return (
      music: music,
      app: MaterialApp(
        theme: actufreeTheme(Brightness.light),
        builder: (BuildContext context, Widget? child) => MusicScope(
          music: music,
          child: child ?? const SizedBox.shrink(),
        ),
        home: HomeMenu(
          title: 'Actufree',
          tagline: 'Free puzzles.',
          settings: settings,
          games: games ??
              <GameEntry>[
                GameEntry(
                  title: 'Sudoku',
                  subtitle: 'Fill the grid',
                  icon: Icons.grid_3x3,
                  onOpen: (BuildContext context) => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          SudokuScreen(puzzle: puzzle),
                    ),
                  ),
                ),
              ],
        ),
      ),
    );
  }

  testWidgets('the menu asks for the menu loop', (tester) async {
    final built = await app();
    addTearDown(built.music.close);
    await tester.pumpWidget(built.app);
    expect(built.music.wanted, MusicTrack.menu);
  });

  testWidgets('opening a game changes the music', (tester) async {
    final built = await app();
    addTearDown(built.music.close);
    await tester.pumpWidget(built.app);

    await tester.tap(find.byKey(const ValueKey<String>('game-Sudoku')));
    await tester.pumpAndSettle();
    expect(built.music.wanted, MusicTrack.match);
  });

  testWidgets('leaving a game hands the music back to the menu', (
    tester,
  ) async {
    final built = await app();
    addTearDown(built.music.close);
    await tester.pumpWidget(built.app);
    await tester.tap(find.byKey(const ValueKey<String>('game-Sudoku')));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(built.music.wanted, MusicTrack.menu);
  });

  testWidgets('a game is still playable when the music cannot be', (
    tester,
  ) async {
    // Nothing here can produce a sound, and the game must not notice. If the
    // service let a plugin failure out, this is the test that would catch it.
    final built = await app();
    addTearDown(built.music.close);
    await tester.pumpWidget(built.app);
    await tester.tap(find.byKey(const ValueKey<String>('game-Sudoku')));
    await tester.pumpAndSettle();

    final sudoku.Cell empty =
        sudoku.Cell.all.firstWhere((c) => puzzle.givens.valueAt(c) == null);
    await tester.tap(find.byKey(ValueKey<String>('cell-${empty.index}')));
    await tester.pump();
    await tester.tap(
      find.byKey(ValueKey<String>('digit-${puzzle.solution.valueAt(empty)}')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('muting does not lose track of what should be playing', (
    tester,
  ) async {
    final built = await app();
    addTearDown(built.music.close);
    await tester.pumpWidget(built.app);
    await built.music.settings.setMusicMuted(true);

    await tester.tap(find.byKey(const ValueKey<String>('game-Sudoku')));
    await tester.pumpAndSettle();
    // Silent, but the game's loop is what is queued up for when the sound
    // comes back — not whatever was playing before the mute.
    expect(built.music.wanted, MusicTrack.match);
  });
}
