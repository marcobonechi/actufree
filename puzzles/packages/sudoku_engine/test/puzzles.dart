/// Fixed puzzles used across the tests.
///
/// Keeping known grids and their known solutions in one place means a solver
/// regression shows up as a diff against a constant rather than against
/// whatever the solver happens to produce today.
library;

/// The grid from the Wikipedia article on Sudoku. Solvable with naked singles
/// alone, so it also exercises the placement-only hint path.
const String easyPuzzle =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';

/// The one completion of [easyPuzzle].
const String easySolution =
    '534678912672195348198342567859761423426853791713924856961537284287419635345286179';

/// Arto Inkala's 2012 puzzle. The implemented techniques stall on it, so it is
/// the case that proves the backtracking fallback works.
const String backtrackingPuzzle =
    '8..........36......7..9.2...5...7.......457.....1...3...1....68..85...1..9....4..';

/// The one completion of [backtrackingPuzzle].
const String backtrackingSolution =
    '812753649943682175675491283154237896369845721287169534521974368438526917796318452';

/// Peter Norvig's "hard1". Notable because the richer technique set here
/// cracks it without guessing, unlike a solver limited to singles.
const String norvigHardPuzzle =
    '4.....8.5.3..........7......2.....6.....8.4......1.......6.3.7.5..2.....1.4......';

/// Four clues: far too few to pin down a single completion.
const String ambiguousPuzzle =
    '1........'
    '.........'
    '.........'
    '.........'
    '....5....'
    '.........'
    '.........'
    '.........'
    '........9';

/// Two 5s in the top row.
const String contradictoryPuzzle =
    '5...5....600195000098000060800060003400803001700020006060000280000419005000080079';
