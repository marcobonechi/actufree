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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  'Sound',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              SwitchListTile(
                key: const ValueKey<String>('music-on'),
                secondary: Icon(
                  settings.musicMuted
                      ? Icons.music_off_outlined
                      : Icons.music_note_outlined,
                ),
                title: const Text('Music'),
                subtitle: const Text('A loop on the menu, another in a game'),
                value: !settings.musicMuted,
                onChanged: (bool on) => settings.setMusicMuted(!on),
              ),
              ListTile(
                leading: const Icon(Icons.volume_up_outlined),
                title: Slider(
                  key: const ValueKey<String>('music-volume'),
                  value: settings.musicVolume,
                  // Named as a percentage: "0.35" is a number the player has
                  // no use for, and it is what a screen reader would say.
                  label: '${(settings.musicVolume * 100).round()}%',
                  divisions: 20,
                  // Greyed rather than hidden while the music is off: the row
                  // staying put says the volume is still set to something,
                  // and the list does not jump as the switch is flipped.
                  onChanged: settings.musicMuted
                      ? null
                      : settings.setMusicVolume,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
