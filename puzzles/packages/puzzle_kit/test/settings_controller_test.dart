import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_kit/puzzle_kit.dart';

void main() {
  test('a fresh install follows the device', () async {
    final settings = await SettingsController.load(MemoryStore());
    expect(settings.themeMode, ThemeMode.system);
  });

  test('a choice is remembered across a restart', () async {
    final store = MemoryStore();
    final settings = await SettingsController.load(store);
    await settings.setThemeMode(ThemeMode.dark);

    final reopened = await SettingsController.load(store);
    expect(reopened.themeMode, ThemeMode.dark);
  });

  test('listeners hear about a change', () async {
    final settings = await SettingsController.load(MemoryStore());
    var notified = 0;
    settings.addListener(() => notified++);

    await settings.setThemeMode(ThemeMode.light);
    expect(notified, 1);
    expect(settings.themeMode, ThemeMode.light);

    // Choosing what is already chosen is not a change.
    await settings.setThemeMode(ThemeMode.light);
    expect(notified, 1);
  });

  test('an unreadable stored value falls back to the device setting',
      () async {
    final store = MemoryStore();
    await store.write('settings/themeMode', 'chartreuse');
    final settings = await SettingsController.load(store);
    expect(settings.themeMode, ThemeMode.system);
  });
}
