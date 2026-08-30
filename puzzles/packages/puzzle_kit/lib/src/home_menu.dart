import 'dart:async';

import 'package:flutter/material.dart';

import 'music_service.dart';
import 'settings_controller.dart';
import 'settings_screen.dart';

/// One game on the home menu.
class GameEntry {
  /// Describes a game.
  const GameEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onOpen,
  });

  /// The game's name.
  final String title;

  /// A line describing it.
  final String subtitle;

  /// The icon shown beside it.
  final IconData icon;

  /// Opens the game. Given the tapped tile's context, so it can navigate.
  final void Function(BuildContext context) onOpen;
}

/// The home menu: the app's name, its games, and the way into settings.
///
/// Built with one game on purpose. The list is the seam a second game slots
/// into, and having it in the shared layer now means the second game arrives
/// as a list entry rather than as a reason to restructure.
class HomeMenu extends StatefulWidget {
  /// Creates the menu.
  const HomeMenu({
    required this.title,
    required this.tagline,
    required this.games,
    required this.settings,
    super.key,
  });

  /// The app's name.
  final String title;

  /// A line under the name.
  final String tagline;

  /// The games on offer.
  final List<GameEntry> games;

  /// Settings, reachable from the menu.
  final SettingsController settings;

  @override
  State<HomeMenu> createState() => _HomeMenuState();
}

class _HomeMenuState extends State<HomeMenu> {
  @override
  void initState() {
    super.initState();
    // The menu is where the app opens and where every game hands back, so
    // this is the one place that has to ask for the menu loop. A game asks
    // for its own on the way in and gives it back on the way out.
    final MusicService? music = MusicScope.maybeOf(context);
    if (music != null) unawaited(music.playMenu());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                key: const ValueKey<String>('open-settings'),
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        SettingsScreen(settings: widget.settings),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    children: <Widget>[
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.tagline,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      for (final game in widget.games)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: Builder(
                              builder: (BuildContext tileContext) => ListTile(
                                key: ValueKey<String>('game-${game.title}'),
                                leading: Icon(
                                  game.icon,
                                  size: 32,
                                  color: theme.colorScheme.primary,
                                ),
                                title: Text(
                                  game.title,
                                  style: theme.textTheme.titleLarge,
                                ),
                                subtitle: Text(game.subtitle),
                                trailing: const Icon(Icons.chevron_right),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                onTap: () => game.onOpen(tileContext),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
