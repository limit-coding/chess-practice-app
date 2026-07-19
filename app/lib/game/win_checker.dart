import 'stone.dart';

/// Checks whether placing [stone] at ([x], [y]) completes a line of five (or
/// more) in any of the four directions: horizontal, vertical, and the two
/// diagonals. [board] is indexed as `board[y][x]`, `null` meaning empty.
///
/// Returns the winning line's coordinates (length >= 5, including the last
/// move) or an empty list if there is no win.
List<(int, int)> checkWin(
  List<List<Stone?>> board,
  int x,
  int y,
  Stone stone,
) {
  const directions = [
    (1, 0), // horizontal
    (0, 1), // vertical
    (1, 1), // diagonal "\"
    (1, -1), // diagonal "/"
  ];

  final size = board.length;
  bool inBounds(int px, int py) => px >= 0 && px < size && py >= 0 && py < size;

  for (final (dx, dy) in directions) {
    final line = <(int, int)>[(x, y)];

    var px = x + dx, py = y + dy;
    while (inBounds(px, py) && board[py][px] == stone) {
      line.add((px, py));
      px += dx;
      py += dy;
    }

    px = x - dx;
    py = y - dy;
    while (inBounds(px, py) && board[py][px] == stone) {
      line.add((px, py));
      px -= dx;
      py -= dy;
    }

    if (line.length >= 5) return line;
  }

  return const [];
}
