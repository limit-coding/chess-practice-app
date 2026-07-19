import 'package:chess_practice/game/stone.dart';
import 'package:chess_practice/game/win_checker.dart';
import 'package:flutter_test/flutter_test.dart';

List<List<Stone?>> _emptyBoard(int size) =>
    List.generate(size, (_) => List<Stone?>.filled(size, null));

void main() {
  group('checkWin', () {
    test('no win on an empty-ish board', () {
      final board = _emptyBoard(15);
      board[7][7] = Stone.black;
      expect(checkWin(board, 7, 7, Stone.black), isEmpty);
    });

    test('horizontal five', () {
      final board = _emptyBoard(15);
      for (var x = 3; x <= 7; x++) {
        board[5][x] = Stone.black;
      }
      final line = checkWin(board, 5, 5, Stone.black);
      expect(line.length, 5);
      expect(line.toSet(), {(3, 5), (4, 5), (5, 5), (6, 5), (7, 5)});
    });

    test('vertical five', () {
      final board = _emptyBoard(15);
      for (var y = 2; y <= 6; y++) {
        board[y][4] = Stone.white;
      }
      final line = checkWin(board, 4, 4, Stone.white);
      expect(line.length, 5);
      expect(line.toSet(), {(4, 2), (4, 3), (4, 4), (4, 5), (4, 6)});
    });

    test('diagonal "\\" five (top-left to bottom-right)', () {
      final board = _emptyBoard(15);
      for (var i = 0; i <= 4; i++) {
        board[i][i] = Stone.black;
      }
      final line = checkWin(board, 2, 2, Stone.black);
      expect(line.length, 5);
      expect(line.toSet(), {(0, 0), (1, 1), (2, 2), (3, 3), (4, 4)});
    });

    test('diagonal "/" five (bottom-left to top-right)', () {
      final board = _emptyBoard(15);
      // x increases, y decreases
      for (var i = 0; i <= 4; i++) {
        board[8 - i][2 + i] = Stone.white;
      }
      final line = checkWin(board, 4, 6, Stone.white);
      expect(line.length, 5);
      expect(
        line.toSet(),
        {(2, 8), (3, 7), (4, 6), (5, 5), (6, 4)},
      );
    });

    test('four in a row is not a win', () {
      final board = _emptyBoard(15);
      for (var x = 3; x <= 6; x++) {
        board[5][x] = Stone.black;
      }
      expect(checkWin(board, 5, 5, Stone.black), isEmpty);
    });

    test('opponent stones do not extend the line', () {
      final board = _emptyBoard(15);
      board[5][2] = Stone.white;
      for (var x = 3; x <= 6; x++) {
        board[5][x] = Stone.black;
      }
      expect(checkWin(board, 5, 5, Stone.black), isEmpty);
    });

    test('overline (six) still counts as a win', () {
      final board = _emptyBoard(15);
      for (var x = 3; x <= 8; x++) {
        board[5][x] = Stone.black;
      }
      final line = checkWin(board, 5, 5, Stone.black);
      expect(line.length, 6);
    });
  });
}
