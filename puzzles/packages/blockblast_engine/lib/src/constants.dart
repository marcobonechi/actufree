/// The board is eight cells on a side.
const int boardSize = 8;

/// The number of cells on the board.
const int cellCount = boardSize * boardSize;

/// How many shapes the player is offered at a time.
const int handSize = 3;

/// How many distinct colours a dealt piece can carry.
///
/// The engine assigns each piece a number in `1..paintCount` and never learns
/// what any of them look like. Which is deliberate: a colour is a drawing
/// concern, and the board still has to remember that *this* square came from a
/// different piece than the one beside it.
const int paintCount = 6;
