import 'piece.dart';
import 'xiangqi_board.dart';
import 'xq_move.dart';
import 'xq_move_record.dart';

/// Game-flow state around [XiangqiBoard]: move history and game-over
/// detection. Xiangqi has no drawn stalemate — being unable to move at all
/// (困毙) is a loss for the side to move, exactly like checkmate, so
/// [winner] only needs to check "does the side to move have any legal
/// move" rather than distinguish the two.
class XiangqiGame {
  XiangqiGame() : board = XiangqiBoard.startPosition();

  final XiangqiBoard board;
  final List<XqMoveRecord> moves = [];

  Side get turn => board.sideToMove;
  bool get isOver => board.hasNoLegalMoves;
  Side? get winner => isOver ? turn.opponent : null;
  bool get isCheckmate => board.isCheckmate;
  bool get isStalemate => board.isStalemate;

  bool canPlay(XqMove move) =>
      !isOver && board.legalMovesFrom(move.fromX, move.fromY).contains(move);

  /// Applies [move] if legal, recording it with the current timestamp.
  /// Returns the recorded move, or `null` if illegal — the board is left
  /// unchanged in that case.
  XqMoveRecord? play(XqMove move) {
    if (!canPlay(move)) return null;
    final side = board.sideToMove;
    board.applyMove(move);
    final record = XqMoveRecord(
      side: side,
      fromX: move.fromX,
      fromY: move.fromY,
      toX: move.toX,
      toY: move.toY,
      timestamp: DateTime.now(),
    );
    moves.add(record);
    return record;
  }

  /// Rebuilds a game by replaying [moves] from the start position — used
  /// for "rewind to this position" the same way GomokuGame.replay is.
  factory XiangqiGame.replay(List<XqMoveRecord> moves) {
    final game = XiangqiGame();
    for (final m in moves) {
      final record = game.play(XqMove(m.fromX, m.fromY, m.toX, m.toY));
      assert(record != null, 'replaying a recorded game must never hit an illegal move');
    }
    return game;
  }
}
