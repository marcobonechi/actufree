import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_kit/puzzle_kit.dart';

void main() {
  const List<Color> palette = <Color>[
    Color(0xFF0072B2),
    Color(0xFFE69F00),
    Color(0xFF009E73),
  ];

  group('the field', () {
    test('starts empty and quiet', () {
      final field = CelebrationField(random: Random(1));
      expect(field.particles, isEmpty);
      expect(field.isActive, isFalse);
    });

    test('a burst throws the number asked for, in the colours given', () {
      final field = CelebrationField(random: Random(1))
        ..burst(origin: const Offset(0.5, 0.5), colors: palette, count: 30);
      expect(field.particles, hasLength(30));
      expect(field.isActive, isTrue);
      for (final particle in field.particles) {
        expect(palette, contains(particle.color));
      }
    });

    test('a burst starts where it was thrown from', () {
      final field = CelebrationField(random: Random(2))
        ..burst(origin: const Offset(0.25, 0.75), colors: palette, count: 12);
      for (final particle in field.particles) {
        expect(particle.position, const Offset(0.25, 0.75));
      }
    });

    test('a burst throws mostly upwards, not down', () {
      // Colour that only ever falls reads as a leak rather than a cheer.
      final field = CelebrationField(random: Random(3))
        ..burst(origin: const Offset(0.5, 0.5), colors: palette, count: 200);
      final rising =
          field.particles.where((CelebrationParticle p) => p.velocity.dy < 0);
      expect(rising.length / field.particles.length, greaterThan(0.7));
    });

    test('a fountain starts below the screen and climbs into it', () {
      final field = CelebrationField(random: Random(4))
        ..fountain(colors: palette, count: 60);
      for (final particle in field.particles) {
        expect(particle.position.dy, greaterThan(1));
        expect(particle.velocity.dy, lessThan(0));
      }
    });

    test('nothing is thrown when there are no colours to throw', () {
      final field = CelebrationField(random: Random(5))
        ..burst(origin: Offset.zero, colors: const <Color>[])
        ..fountain(colors: const <Color>[]);
      expect(field.isActive, isFalse);
    });

    test('what goes up comes down', () {
      final field = CelebrationField(random: Random(6))
        ..fountain(colors: palette, count: 40);
      final highest = <double>[];
      for (var step = 0; step < 40; step++) {
        field.advance(1 / 60);
        if (field.particles.isEmpty) break;
        highest.add(
          field.particles
              .map((CelebrationParticle p) => p.position.dy)
              .reduce(min),
        );
      }
      // It rises for a while and then stops rising: gravity is doing its job.
      expect(highest.first, greaterThan(highest[highest.length ~/ 3]));
    });

    test('a burst settles instead of running for ever', () {
      final field = CelebrationField(random: Random(7))
        ..burst(origin: const Offset(0.5, 0.5), colors: palette, count: 60);
      var seconds = 0.0;
      while (field.isActive && seconds < 30) {
        field.advance(1 / 60);
        seconds += 1 / 60;
      }
      expect(field.isActive, isFalse, reason: 'still going after ${seconds}s');
      expect(seconds, lessThan(6), reason: 'outstayed its welcome');
    });

    test('particles fade rather than blinking out', () {
      final field = CelebrationField(random: Random(8))
        ..burst(origin: const Offset(0.5, 0.5), colors: palette, count: 20);
      expect(field.particles.first.opacity, 1);
      while (field.particles.isNotEmpty &&
          field.particles.first.opacity == 1) {
        field.advance(1 / 60);
      }
      if (field.particles.isNotEmpty) {
        expect(field.particles.first.opacity, lessThan(1));
        expect(field.particles.first.opacity, greaterThan(0));
      }
    });

    test('standing still changes nothing', () {
      final field = CelebrationField(random: Random(9))
        ..burst(origin: const Offset(0.5, 0.5), colors: palette, count: 10);
      final before = field.particles.first.position;
      field.advance(0);
      expect(field.particles.first.position, before);
    });
  });

  group('the scope', () {
    testWidgets('a screen finds the cue the app put up', (tester) async {
      final cue = CelebrationCue();
      CelebrationCue? found;
      await tester.pumpWidget(
        MaterialApp(
          home: CelebrationScope(
            cue: cue,
            child: Builder(
              builder: (BuildContext context) {
                found = CelebrationScope.maybeOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(found, same(cue));
    });

    testWidgets('a screen on its own finds nothing, and does not mind', (
      tester,
    ) async {
      CelebrationCue? found = CelebrationCue();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              found = CelebrationScope.maybeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(found, isNull);
    });
  });

  group('the layer', () {
    Widget host(CelebrationCue cue, {bool noAnimations = false}) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: noAnimations),
            child: CelebrationLayer(
              cue: cue,
              child: const SizedBox.expand(child: Text('board')),
            ),
          ),
        );

    testWidgets('it draws nothing until it is asked to', (tester) async {
      await tester.pumpWidget(host(CelebrationCue()));
      expect(find.byKey(celebrationPaintKey), findsNothing);
      expect(find.text('board'), findsOneWidget);
    });

    testWidgets('a cue puts colour on the screen, and it clears up', (
      tester,
    ) async {
      final cue = CelebrationCue();
      await tester.pumpWidget(host(cue));
      cue.fountain(colors: palette);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(celebrationPaintKey), findsWidgets);

      await tester.pumpAndSettle(const Duration(milliseconds: 32));
      expect(find.byKey(celebrationPaintKey), findsNothing, reason: 'never stopped');
    });

    testWidgets('the child stays tappable underneath', (tester) async {
      // A celebration that ate a tap would cost the player their next move.
      var taps = 0;
      final cue = CelebrationCue();
      await tester.pumpWidget(
        MaterialApp(
          home: CelebrationLayer(
            cue: cue,
            child: GestureDetector(
              onTap: () => taps++,
              child: const SizedBox.expand(
                child: ColoredBox(
                  key: ValueKey<String>('under'),
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ),
      );
      cue.fountain(colors: palette);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      await tester.tap(find.byKey(const ValueKey<String>('under')));
      expect(taps, 1);
      await tester.pumpAndSettle(const Duration(milliseconds: 32));
    });

    testWidgets('it stays still when the system asks for no animations', (
      tester,
    ) async {
      final cue = CelebrationCue();
      await tester.pumpWidget(host(cue, noAnimations: true));
      cue.fountain(colors: palette);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(celebrationPaintKey), findsNothing);
    });
  });
}
