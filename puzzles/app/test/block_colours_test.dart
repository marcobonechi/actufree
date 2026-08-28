import 'package:blockblast_engine/blockblast_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles_app/theme.dart';

void main() {
  test('every set has one colour per paint value', () {
    for (final set in BlockColours.all) {
      expect(set.pieces, hasLength(paintCount), reason: set.name);
    }
  });

  test('no set repeats a colour', () {
    for (final set in BlockColours.all) {
      expect(set.pieces.toSet(), hasLength(set.pieces.length), reason: set.name);
    }
  });

  test('the sets differ from one another', () {
    final seen = <String>{};
    for (final set in BlockColours.all) {
      expect(seen.add(set.pieces.toString()), isTrue, reason: set.name);
      expect(seen.add(set.name), isTrue);
    }
  });

  test('no set contains a yellow, which is reserved for the clear flash', () {
    // A guard against a yellow being added, not a claim about perceptual
    // distance: it catches a colour that reads as the same colour as the
    // flash, and nothing subtler. What keeps the sets distinguishable under
    // colour blindness is that each one is a published scheme with that
    // property, which no assertion here can stand in for.
    final flash = HSLColor.fromColor(BlockPalette.light.clearFlash);
    for (final set in BlockColours.all) {
      for (final colour in set.pieces) {
        final hsl = HSLColor.fromColor(colour);
        var hue = (hsl.hue - flash.hue).abs();
        if (hue > 180) hue = 360 - hue;
        expect(
          hue < 10 && (hsl.lightness - flash.lightness).abs() < 0.1,
          isFalse,
          reason: '${set.name}: $colour reads as the clear flash',
        );
      }
    }
  });

  test('the yellow guard would actually catch a yellow', () {
    // A threshold nothing ever trips is not a guard. Tol's sand and his
    // bright yellow are the two most likely additions to a future set, and
    // both must be refused.
    final flash = HSLColor.fromColor(BlockPalette.light.clearFlash);
    for (final yellow in <Color>[
      const Color(0xFFCCBB44), // Tol bright yellow
      const Color(0xFFDDCC77), // Tol muted sand
      BlockPalette.light.clearFlash,
    ]) {
      final hsl = HSLColor.fromColor(yellow);
      var hue = (hsl.hue - flash.hue).abs();
      if (hue > 180) hue = 360 - hue;
      expect(
        hue < 10 && (hsl.lightness - flash.lightness).abs() < 0.1,
        isTrue,
        reason: '$yellow slipped past the guard',
      );
    }
  });

  test('every block stands out from the board by brightness alone', () {
    // Not by hue. A colour that is only distinguishable from the board by
    // being a different colour disappears for anyone who cannot see the
    // difference — which is the entire reason these sets are curated.
    //
    // The thresholds are set from measurement: every colour that ships clears
    // 0.29 against the light board and 0.11 against the dark one, so these sit
    // just below with room to be tightened rather than loosened.
    final light = BlockPalette.light.emptyCell.computeLuminance();
    final dark = BlockPalette.dark.emptyCell.computeLuminance();
    for (final set in BlockColours.all) {
      for (final colour in set.pieces) {
        final lum = colour.computeLuminance();
        expect(
          light - lum,
          greaterThan(0.25),
          reason: '${set.name}: $colour is too pale for the light board',
        );
        expect(
          lum - dark,
          greaterThan(0.1),
          reason: '${set.name}: $colour is too dark for the dark board',
        );
      }
    }
  });

  group('rotation', () {
    test('a new game starts on the first set', () {
      expect(coloursFor(0), BlockColours.all.first);
      expect(coloursFor(kColourInterval - 1), BlockColours.all.first);
    });

    test('the set changes as the score passes each interval', () {
      expect(coloursFor(kColourInterval), BlockColours.all[1]);
      expect(coloursFor(kColourInterval * 2), BlockColours.all[2]);
    });

    test('the sets come round again rather than running out', () {
      final count = BlockColours.all.length;
      expect(coloursFor(kColourInterval * count), BlockColours.all.first);
      expect(coloursFor(kColourInterval * (count + 1)), BlockColours.all[1]);
    });

    test('consecutive intervals never repeat a set', () {
      // A colour change that changes nothing is the one thing this is meant to
      // avoid, which is why the sets rotate rather than being drawn at random.
      for (var step = 0; step < 24; step++) {
        expect(
          coloursFor(step * kColourInterval),
          isNot(coloursFor((step + 1) * kColourInterval)),
          reason: 'step $step',
        );
      }
    });

    test('a resumed run comes back in the colours it was left in', () {
      // Derived from the score, so the save never has to carry it.
      const score = kColourInterval * 4 + 37;
      expect(coloursFor(score), coloursFor(score));
      expect(coloursFor(score), BlockColours.all[4 % BlockColours.all.length]);
    });
  });
}
