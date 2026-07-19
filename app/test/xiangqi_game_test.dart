import 'package:chess_practice/xiangqi/piece.dart';
import 'package:chess_practice/xiangqi/xiangqi_game.dart';
import 'package:chess_practice/xiangqi/xq_move.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('XiangqiGame', () {
    test('starts with Red to move and no winner', () {
      final game = XiangqiGame();
      expect(game.turn, Side.red);
      expect(game.isOver, isFalse);
      expect(game.winner, isNull);
    });

    test('play() applies a legal opening move and records it', () {
      final game = XiangqiGame();
      // Red cannon h2-e2 (a common opening): file h=7, rank 2 -> file e=4, rank 2.
      final record = game.play(const XqMove(7, 2, 4, 2));
      expect(record, isNotNull);
      expect(record!.side, Side.red);
      expect(game.turn, Side.black);
      expect(game.moves.length, 1);
      expect(game.board.at(4, 2)?.type, PieceType.cannon);
      expect(game.board.at(7, 2), isNull);
    });

    test('play() rejects an illegal move without mutating state', () {
      final game = XiangqiGame();
      final movesBefore = game.moves.length;
      final turnBefore = game.turn;
      // Soldier at (0,3) cannot jump to (0,5).
      final record = game.play(const XqMove(0, 3, 0, 5));
      expect(record, isNull);
      expect(game.moves.length, movesBefore);
      expect(game.turn, turnBefore);
    });

    test('replay reconstructs the exact same position', () {
      final game = XiangqiGame();
      final played = [
        const XqMove(7, 2, 4, 2), // red cannon h2e2
        const XqMove(1, 7, 4, 7), // black cannon b7e7
      ];
      for (final m in played) {
        game.play(m);
      }
      final replay = XiangqiGame.replay(game.moves);
      for (var y = 0; y < 10; y++) {
        for (var x = 0; x < 9; x++) {
          expect(replay.board.at(x, y), game.board.at(x, y), reason: 'square ($x,$y)');
        }
      }
      expect(replay.turn, game.turn);
    });

    test('a side with no legal moves loses (checkmate or 困毙 alike)', () {
      final game = XiangqiGame();
      // Reuse the checkmate geometry from xiangqi_board_test.dart directly
      // on a fresh game by driving it through applyMove on the board.
      game.board.squares[0][3] = const XqPiece(PieceType.king, Side.red);
      game.board.squares[5][3] = const XqPiece(PieceType.chariot, Side.black);
      game.board.squares[0][8] = const XqPiece(PieceType.chariot, Side.black);
      // Clear the rest of the board so nothing else interferes.
      for (var y = 0; y < 10; y++) {
        for (var x = 0; x < 9; x++) {
          if ((x == 3 && y == 0) || (x == 3 && y == 5) || (x == 8 && y == 0)) continue;
          game.board.squares[y][x] = null;
        }
      }
      expect(game.isOver, isTrue);
      expect(game.winner, Side.black);
      expect(game.isCheckmate, isTrue);
    });
  });
}
