import 'package:flutter/material.dart';
import 'package:puzzle_kit/puzzle_kit.dart';

import 'sudoku/difficulty_screen.dart';

/// The Actufree menu: pick a game.
///
/// Sudoku is the only one so far. The list is the seam Block Blast slots into.
class HomeScreen extends StatelessWidget {
  /// Creates the menu.
  const HomeScreen({required this.store, super.key});

  /// Where games in progress are kept.
  final GameStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                Text(
                  'Actufree',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Free puzzles. No ads, no accounts, nothing collected.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                _GameTile(
                  title: 'Sudoku',
                  subtitle: 'Fill the grid, one to nine',
                  icon: Icons.grid_3x3,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          DifficultyScreen(store: store),
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

class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: ValueKey<String>('game-$title'),
        leading: Icon(icon, size: 32, color: theme.colorScheme.primary),
        title: Text(title, style: theme.textTheme.titleLarge),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: onTap,
      ),
    );
  }
}
