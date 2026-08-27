import 'package:flutter/material.dart';

import 'settings_controller.dart';

/// The settings screen.
class SettingsScreen extends StatelessWidget {
  /// Edits [settings].
  const SettingsScreen({required this.settings, super.key});

  /// The settings being edited.
  final SettingsController settings;

  static const Map<ThemeMode, ({String label, IconData icon})> _themeOptions =
      <ThemeMode, ({String label, IconData icon})>{
    ThemeMode.system: (label: 'Use device setting', icon: Icons.brightness_auto),
    ThemeMode.light: (label: 'Light', icon: Icons.light_mode_outlined),
    ThemeMode.dark: (label: 'Dark', icon: Icons.dark_mode_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: settings,
          builder: (BuildContext context, _) => ListView(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Appearance',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              for (final entry in _themeOptions.entries)
                ListTile(
                  key: ValueKey<String>('theme-${entry.key.name}'),
                  leading: Icon(entry.value.icon),
                  title: Text(entry.value.label),
                  trailing: settings.themeMode == entry.key
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  selected: settings.themeMode == entry.key,
                  onTap: () => settings.setThemeMode(entry.key),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
