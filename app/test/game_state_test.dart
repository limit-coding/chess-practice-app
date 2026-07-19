import 'package:chess_practice/game/game_state.dart';
import 'package:chess_practice/game/stone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GomokuGame', () {
    test('black moves first', () {
      final game = GomokuGame(boardSize: 15);
      expect(game.turn, Stone.black);
    });

    test('turn alternates and board stays consistent across many moves', () {
      final game = GomokuGame(boardSize: 15);
      final coords = [
        (7, 7), (7, 8), (8, 7), (8, 8), (6, 7), (6, 8), (5, 7), (5, 8),
      ];
      for (final (x, y) in coords) {
        final beforeTurn = game.turn;
        final record = game.play(x, y);
        expect(record, isNotNull);
        expect(record!.stone, beforeTurn);
        expect(game.board[y][x], beforeTurn);
        expect(game.turn, beforeTurn.opponent);
      }
      expect(game.moves.length, coords.length);
      // No stray writes outside the played cells.
      var occupied = 0;
      for (final row in game.board) {
        occupied += row.where((s) => s != null).length;
      }
      expect(occupied, coords.length);
    });

    test('rejects occupied cell without mutating state', () {
      final game = GomokuGame(boardSize: 15);
      game.play(7, 7);
      final turnBefore = game.turn;
      final movesBefore = game.moves.length;
      final result = game.play(7, 7);
      expect(result, isNull);
      expect(game.turn, turnBefore);
      expect(game.moves.length, movesBefore);
    });

    test('rejects out-of-bounds cell', () {
      final game = GomokuGame(boardSize: 15);
      expect(game.play(-1, 0), isNull);
      expect(game.play(15, 0), isNull);
      expect(game.moves, isEmpty);
    });

    test('ends the game and stops accepting moves once someone wins', () {
      final game = GomokuGame(boardSize: 15);
      // Black: (0,0)(1,0)(2,0)(3,0)(4,0); White: (0,1)(1,1)(2,1)(3,1)
      final blackXs = [0, 1, 2, 3, 4];
      final whiteXs = [0, 1, 2, 3];
      for (var i = 0; i < blackXs.length; i++) {
        game.play(blackXs[i], 0);
        if (i < whiteXs.length) game.play(whiteXs[i], 1);
      }
      expect(game.isOver, isTrue);
      expect(game.winner, Stone.black);
      expect(game.winningLine.length, 5);
      expect(game.canPlay(5, 5), isFalse);
      expect(game.play(5, 5), isNull);
    });
  });
}
