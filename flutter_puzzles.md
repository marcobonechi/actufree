# Project Brief: Flutter Puzzle Collection

## Context

I'm building a small collection of classic puzzle games as a hobby project. This is not a commercial product: **no ads, no in-app purchases, no analytics, no tracking, no third-party SDKs of any kind.** Nothing gets collected, nothing phones home. Assume every dependency has to justify itself.

Two games to start:

1. **Sudoku** — standard 9x9, multiple difficulty levels
2. **Block Blast / block-crush** — drag tetromino-ish shapes onto an 8x8 grid, clear full rows and columns, play until no shape fits

Both ship as a **single app** with a menu screen, not two separate apps. This is deliberate — one store listing per platform, one review cycle, one signing setup.

I'm developing on a Mac, targeting iOS and Android. I'm already comfortable with Flutter and Dart.

## Stack decision (already made — don't relitigate)

Flutter + Dart. I evaluated Unity (overkill: a 3D engine used for grid-and-tap games, bloated builds, license tier to track) and Godot (great, but I don't want to learn a new engine for two games that are essentially grid UIs). Flutter it is.

No Flame in the shared layer. If a future game genuinely needs a game loop, it can add Flame as a leaf dependency without dragging the shared code along.

## Architecture

Dart workspace monorepo:

```
puzzles/
  pubspec.yaml          # workspace root
  app/                  # the shipped Flutter app
  packages/
    puzzle_kit/         # shared Flutter layer
    sudoku_engine/      # pure Dart
    blockblast_engine/  # pure Dart
```

### The one hard rule

**Game engines are pure Dart with zero Flutter imports.** No `package:flutter/*`, no `dart:ui`, no widgets, no `Color`, no `Offset`. An engine knows the rules of its game and nothing about how it's drawn. This makes them testable in milliseconds via `dart test` with no simulator, and it means a UI rewrite never touches game logic. This constraint is non-negotiable — if something seems to need a Flutter type, that's a signal the boundary is in the wrong place.

Create engines with `dart create -t package <name>`, not `flutter create`, so the Flutter dependency is never available to be accidentally added.

### What belongs in `puzzle_kit`

Shared cross-game concerns:

- **Undo/redo** — generic command stack, both games need it
- **Save/resume** — serialize game state to disk, restore on launch. Define a `SavedGame` interface each engine implements
- **Settings + theme** — dark mode, sound on/off, haptics, colorblind-safe palette
- **Audio + haptics wrapper** — thin layer so the underlying plugin can be swapped in one place
- **Stats** — games played, best times, per-difficulty records, streaks
- **Shell UI** — home menu, pause dialog, settings screen, win/lose screen, responsive board sizing that respects safe areas

### What explicitly does NOT belong in `puzzle_kit`

**A generic grid widget.** Sudoku's fixed 9x9 with region borders and a number pad, versus Block Blast's drag-a-shape-onto-a-board with snap previews, are different enough that a shared grid abstraction will fight both of them. Write each board widget directly. Factor out only what actually repeats, and only after the second game exists.

## Current state

Nothing built yet. Fresh start.

## Phase 0 — Verify the toolchain

Run `flutter doctor` and report anything broken before writing code. Likely needed on a fresh Mac: `xcodebuild -runFirstLaunch`, `sudo xcodebuild -license`, and Android Studio installed for its SDK and emulator.

## Phase 1 — Scaffold

Set up the workspace so a single `dart pub get` at the root resolves everything:

- Root `pubspec.yaml` with a `workspace:` field listing `app`, `packages/puzzle_kit`, `packages/sudoku_engine`
- `resolution: workspace` in each member package's pubspec
- `app` depends on the packages via `path` entries
- Confirm the default counter app builds and runs on the iOS Simulator before going further

Don't scaffold `blockblast_engine` yet.

## Phase 2 — Sudoku engine (the actual first task)

Build `sudoku_engine` completely, with tests, **before writing a single widget.** This is self-contained, pure logic, and fast to iterate on.

Needs:

- **Board representation** — immutable where practical, with a clear distinction between given clues and player-entered values. Support for pencil marks / candidate notes.
- **Solver** — constraint propagation (naked singles, hidden singles) with backtracking fallback. Must be able to answer "does this puzzle have exactly one solution?"
- **Generator** — produces puzzles with a **guaranteed unique solution**. Standard approach: generate a full valid grid, then remove clues one at a time, checking uniqueness after each removal.
- **Difficulty rating** — derived from which solving techniques are required, not from clue count. Clue count is a poor proxy. Expose named tiers (Easy / Medium / Hard / Expert).
- **Move validation** — is this entry legal given current state, and does it conflict with anything.
- **Hint system** — return the next logically deducible cell plus which technique justifies it.

### Testing expectations

- `dart test` must pass with meaningful coverage of the engine
- Solver correctness against known puzzles, including at least one that requires backtracking
- Generator uniqueness verified across many generated puzzles
- Generator determinism when given a seed, so bugs are reproducible
- Generation performance is reasonable — a hard puzzle shouldn't take seconds

## Conventions

- Dart 3, sound null safety, `package:lints` recommended set or stricter
- Prefer immutable value types and explicit state transitions over mutable objects with side effects
- **Ask before adding any dependency.** Given the no-tracking stance, I want to see and approve every package that lands in `pubspec.yaml`.
- Small, reviewable commits with clear messages

## Deferred — don't build these yet

Sudoku UI, Block Blast entirely, audio, persistence, App Store / Play Store configuration, app icons, splash screens. I'll ask when it's time.

## How I'd like you to work

Start with Phase 0 and report what you find. Then scaffold, verify it runs, and move to the Sudoku engine. Show me the engine's public API surface before implementing the internals — I'd rather correct the shape of it early than after there's a solver hanging off it.
