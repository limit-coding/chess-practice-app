import 'move_record.dart';
import 'stone.dart';
import 'win_checker.dart';

/// Mutable state for one Gomoku game: the board, move history, whose turn it
/// is, and (once the game ends) the winner and winning line.
///
/// Black always moves first and is always the human player; White is always
/// the engine (see [GamePage] wiring in lib/pages/game_page.dart).
class GomokuGame {
  GomokuGame({this.boardSize = 15})
      : board = List.generate(
          boardSize,
          (_) => List<Stone?>.filled(boardSize, null),
        );

  final int boardSize;
  final List<List<Stone?>> board;
  final List<MoveRecord> moves = [];

  /// Rebuilds the board by replaying [moves] from an empty board — used by
  /// review's "rewind to this position" (step 2.4). Purely local replay, so
  /// the result is guaranteed to match the original game bit-for-bit; no
  /// engine round-trip involved.
  factory GomokuGame.replay(int boardSize, List<MoveRecord> moves) {
    final game = GomokuGame(boardSize: boardSize);
    for (final m in moves) {
      final record = game.play(m.x, m.y);
      assert(record != null, 'replaying a recorded game must never hit an illegal move');
    }
    return game;
  }

  Stone turn = Stone.black;
  Stone? winner;
  List<(int, int)> winningLine = const [];

  bool get isOver => winner != null || isDraw;
  bool get isDraw => winner == null && moves.length == boardSize * boardSize;

  bool inBounds(int x, int y) => x >= 0 && x < boardSize && y >= 0 && y < boardSize;

  bool isEmpty(int x, int y) => inBounds(x, y) && board[y][x] == null;

  bool canPlay(int x, int y) => !isOver && isEmpty(x, y);

  /// Places the stone whose turn it currently is at ([x], [y]). Returns the
  /// recorded move, or `null` if the move is illegal (out of bounds,
  /// occupied, or the game already ended) — the board is left unchanged.
  MoveRecord? play(int x, int y) {
    if (!canPlay(x, y)) return null;

    final stone = turn;
    board[y][x] = stone;
    final record = MoveRecord(
      stone: stone,
      x: x,
      y: y,
      timestamp: DateTime.now(),
    );
    moves.add(record);

    final line = checkWin(board, x, y, stone);
    if (line.isNotEmpty) {
      winner = stone;
      winningLine = line;
    } else {
      turn = stone.opponent;
    }

    return record;
  }
}
