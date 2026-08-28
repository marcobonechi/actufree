import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_kit/puzzle_kit.dart';

/// The gradient [PuzzleBackdrop] is painting.
Gradient paintedBy(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(PuzzleBackdrop),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).gradient!;
}

void main() {
  ColorScheme schemeFor(Brightness brightness) =>
      ColorScheme.fromSeed(seedColor: const Color(0xFF0072B2), brightness: brightness);

  test('the backdrop runs between two ends, through the surface', () {
    for (final brightness in Brightness.values) {
      final scheme = schemeFor(brightness);
      final gradient = backdropGradient(scheme) as LinearGradient;
      expect(gradient.colors, hasLength(3), reason: '$brightness');
      expect(gradient.colors[1], scheme.surface, reason: '$brightness');
      expect(gradient.colors.first, isNot(gradient.colors.last));
    }
  });

  test('it stays gentle: no end strays far from the surface', () {
    // The whole point is a backdrop nobody notices. A board is a grid of
    // coloured squares, and anything with real contrast behind it would be
    // competing all game.
    for (final brightness in Brightness.values) {
      final scheme = schemeFor(brightness);
      final gradient = backdropGradient(scheme) as LinearGradient;
      final surface = scheme.surface.computeLuminance();
      for (final end in <Color>[gradient.colors.first, gradient.colors.last]) {
        expect(
          (end.computeLuminance() - surface).abs(),
          lessThan(0.16),
          reason: '$brightness: $end is too far from the surface',
        );
      }
    }
  });

  test('light gets lighter upward, dark gets darker downward', () {
    // A dark screen that brightens towards the bottom reads upside down.
    final light = backdropGradient(schemeFor(Brightness.light)) as LinearGradient;
    expect(
      light.colors.first.computeLuminance(),
      greaterThan(light.colors.last.computeLuminance()),
    );
    final dark = backdropGradient(schemeFor(Brightness.dark)) as LinearGradient;
    expect(
      dark.colors.first.computeLuminance(),
      greaterThan(dark.colors.last.computeLuminance()),
    );
  });

  testWidgets('the backdrop follows the theme it is given', (tester) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(brightness: brightness),
          home: const PuzzleBackdrop(child: SizedBox.expand()),
        ),
      );
      // MaterialApp animates a theme change, so without settling the second
      // pass would still be looking at the first brightness on its way out.
      await tester.pumpAndSettle();
      expect(
        paintedBy(tester),
        backdropGradient(schemeFor(brightness)),
        reason: '$brightness',
      );
    }
  });

  testWidgets('the scaffold and app bar keep out of its way', (tester) async {
    // Either one painting its own flat panel would hide the backdrop behind
    // exactly the screens it exists for.
    for (final brightness in Brightness.values) {
      final theme = buildTheme(brightness: brightness);
      expect(theme.scaffoldBackgroundColor, Colors.transparent);
      expect(theme.appBarTheme.backgroundColor, Colors.transparent);
      expect(theme.appBarTheme.elevation, 0);
    }
  });
}
