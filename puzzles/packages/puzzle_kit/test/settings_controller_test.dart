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

  test('music is on, at a sensible volume, on a fresh install', () async {
    final settings = await SettingsController.load(MemoryStore());
    expect(settings.musicMuted, isFalse);
    expect(settings.musicVolume, SettingsController.defaultMusicVolume);
  });

  test('muting and the volume are both remembered across a restart', () async {
    final store = MemoryStore();
    final settings = await SettingsController.load(store);
    await settings.setMusicMuted(true);
    await settings.setMusicVolume(0.8);

    final reopened = await SettingsController.load(store);
    expect(reopened.musicMuted, isTrue);
    expect(reopened.musicVolume, 0.8);
  });

  test('muting leaves the volume where it was', () async {
    // So unmuting gives the player their level back rather than making them
    // find it again.
    final settings = await SettingsController.load(MemoryStore());
    await settings.setMusicVolume(0.9);
    await settings.setMusicMuted(true);
    expect(settings.musicVolume, 0.9);
  });

  test('a volume past either end is pulled back into range', () async {
    final settings = await SettingsController.load(MemoryStore());
    await settings.setMusicVolume(4);
    expect(settings.musicVolume, 1);
    await settings.setMusicVolume(-1);
    expect(settings.musicVolume, 0);
  });

  test('an unreadable stored volume falls back to the default', () async {
    final store = MemoryStore();
    await store.write('settings/musicVolume', 'fortissimo');
    final settings = await SettingsController.load(store);
    expect(settings.musicVolume, SettingsController.defaultMusicVolume);
  });

  test('setting the volume it already has is not a change', () async {
    final settings = await SettingsController.load(MemoryStore());
    var notified = 0;
    settings.addListener(() => notified++);
    await settings.setMusicVolume(0.6);
    await settings.setMusicVolume(0.6);
    expect(notified, 1);
  });
}
