import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_kit/puzzle_kit.dart';

void main() {
  Future<SettingsController> freshSettings() =>
      SettingsController.load(MemoryStore());

  Widget host(SettingsController settings, {List<GameEntry>? games}) {
    return AnimatedBuilder(
      animation: settings,
      builder: (BuildContext context, _) => MaterialApp(
        theme: buildTheme(brightness: Brightness.light),
        darkTheme: buildTheme(brightness: Brightness.dark),
        themeMode: settings.themeMode,
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
                      builder: (BuildContext context) => const Scaffold(
                        body: Center(child: Text('the game')),
                      ),
                    ),
                  ),
                ),
              ],
        ),
      ),
    );
  }

  group('home menu', () {
    testWidgets('shows the app name and its games', (tester) async {
      await tester.pumpWidget(host(await freshSettings()));
      expect(find.text('Actufree'), findsOneWidget);
      expect(find.text('Sudoku'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('game-Sudoku')), findsOneWidget);
    });

    testWidgets('opening a game navigates', (tester) async {
      await tester.pumpWidget(host(await freshSettings()));
      await tester.tap(find.byKey(const ValueKey<String>('game-Sudoku')));
      await tester.pumpAndSettle();
      expect(find.text('the game'), findsOneWidget);
    });

    testWidgets('lists every game it is given', (tester) async {
      // One game today, but the list is the seam a second slots into.
      await tester.pumpWidget(host(
        await freshSettings(),
        games: <GameEntry>[
          for (final name in <String>['Sudoku', 'Block Blast'])
            GameEntry(
              title: name,
              subtitle: 'x',
              icon: Icons.games,
              onOpen: (BuildContext context) {},
            ),
        ],
      ));
      expect(find.byKey(const ValueKey<String>('game-Sudoku')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('game-Block Blast')),
        findsOneWidget,
      );
    });
  });

  group('settings', () {
    testWidgets('are reachable from the menu', (tester) async {
      await tester.pumpWidget(host(await freshSettings()));
      await tester.tap(find.byKey(const ValueKey<String>('open-settings')));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Use device setting'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('choosing dark repaints the app dark', (tester) async {
      final settings = await freshSettings();
      await tester.pumpWidget(host(settings));
      await tester.tap(find.byKey(const ValueKey<String>('open-settings')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('theme-dark')));
      await tester.pumpAndSettle();

      expect(settings.themeMode, ThemeMode.dark);
      final context = tester.element(find.text('Dark'));
      expect(Theme.of(context).brightness, Brightness.dark);
    });

    testWidgets('the current choice is ticked', (tester) async {
      final settings = await freshSettings();
      await settings.setThemeMode(ThemeMode.light);
      await tester.pumpWidget(host(settings));
      await tester.tap(find.byKey(const ValueKey<String>('open-settings')));
      await tester.pumpAndSettle();

      final ticked = tester.widget<ListTile>(
        find.byKey(const ValueKey<String>('theme-light')),
      );
      expect(ticked.selected, isTrue);
      expect(ticked.trailing, isNotNull);
      final unticked = tester.widget<ListTile>(
        find.byKey(const ValueKey<String>('theme-dark')),
      );
      expect(unticked.selected, isFalse);
      expect(unticked.trailing, isNull);
    });
  });
}
