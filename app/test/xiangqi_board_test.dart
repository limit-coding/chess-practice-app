import 'package:chess_practice/xiangqi/piece.dart';
import 'package:chess_practice/xiangqi/xiangqi_board.dart';
import 'package:chess_practice/xiangqi/xq_move.dart';
import 'package:flutter_test/flutter_test.dart';

XiangqiBoard emptyBoard({Side sideToMove = Side.red}) => XiangqiBoard(
      squares: List.generate(10, (_) => List<XqPiece?>.filled(9, null)),
      sideToMove: sideToMove,
    );

void main() {
  group('start position', () {
    test('has 16 pieces per side in the right places', () {
      final b = XiangqiBoard.startPosition();
      expect(b.sideToMove, Side.red);
      expect(b.at(0, 0), const XqPiece(PieceType.chariot, Side.red));
      expect(b.at(4, 0), const XqPiece(PieceType.king, Side.red));
      expect(b.at(4, 9), const XqPiece(PieceType.king, Side.black));
      expect(b.at(1, 2), const XqPiece(PieceType.cannon, Side.red));
      expect(b.at(0, 3), const XqPiece(PieceType.soldier, Side.red));
      expect(b.at(4, 4), isNull); // river area empty
      expect(b.isInCheck(Side.red), isFalse);
      expect(b.isInCheck(Side.black), isFalse);
    });

    test('round-trips through FEN', () {
      final b = XiangqiBoard.startPosition();
      final b2 = XiangqiBoard.fromFen('${b.toFenFields()} - - 0 1');
      for (var y = 0; y < 10; y++) {
        for (var x = 0; x < 9; x++) {
          expect(b2.at(x, y), b.at(x, y), reason: 'square ($x,$y)');
        }
      }
    });
  });

  group('chariot (车)', () {
    test('slides until blocked, can capture the first enemy in its path', () {
      final b = emptyBoard()
        ..squares[5][4] = const XqPiece(PieceType.chariot, Side.red)
        ..squares[5][7] = const XqPiece(PieceType.soldier, Side.black)
        ..squares[5][1] = const XqPiece(PieceType.soldier, Side.red);
      final moves = b.pseudoLegalMovesFrom(4, 5).toSet();
      expect(moves, containsAll([
        const XqMove(4, 5, 5, 5),
        const XqMove(4, 5, 6, 5),
        const XqMove(4, 5, 7, 5), // capture
        const XqMove(4, 5, 3, 5), // short of the own piece at x=1
        const XqMove(4, 5, 2, 5),
      ]));
      expect(moves, isNot(contains(const XqMove(4, 5, 8, 5)))); // beyond capture
      expect(moves, isNot(contains(const XqMove(4, 5, 1, 5)))); // own piece
      expect(moves, isNot(contains(const XqMove(4, 5, 0, 5)))); // beyond own piece
    });
  });

  group('cannon (炮)', () {
    test('moves like a chariot without a screen, must jump exactly one to capture', () {
      final b = emptyBoard()
        ..squares[5][4] = const XqPiece(PieceType.cannon, Side.red)
        ..squares[5][6] = const XqPiece(PieceType.soldier, Side.red) // screen
        ..squares[5][8] = const XqPiece(PieceType.soldier, Side.black); // capturable
      final moves = b.pseudoLegalMovesFrom(4, 5).toSet();
      // Quiet moves up to (not through) the screen.
      expect(moves, contains(const XqMove(4, 5, 5, 5)));
      expect(moves, isNot(contains(const XqMove(4, 5, 6, 5)))); // screen square itself
      // Capture landing exactly on the piece beyond the screen.
      expect(moves, contains(const XqMove(4, 5, 8, 5)));
      expect(moves, isNot(contains(const XqMove(4, 5, 7, 5)))); // between screen and target
    });

    test('cannot capture without a screen in between', () {
      final b = emptyBoard()
        ..squares[5][4] = const XqPiece(PieceType.cannon, Side.red)
        ..squares[5][7] = const XqPiece(PieceType.soldier, Side.black);
      final moves = b.pseudoLegalMovesFrom(4, 5).toSet();
      expect(moves, isNot(contains(const XqMove(4, 5, 7, 5))));
      expect(moves, contains(const XqMove(4, 5, 6, 5))); // quiet move short of it
    });

    test('cannot capture own piece even across a screen', () {
      final b = emptyBoard()
        ..squares[5][4] = const XqPiece(PieceType.cannon, Side.red)
        ..squares[5][6] = const XqPiece(PieceType.soldier, Side.black) // screen
        ..squares[5][8] = const XqPiece(PieceType.soldier, Side.red); // own piece
      final moves = b.pseudoLegalMovesFrom(4, 5).toSet();
      expect(moves, isNot(contains(const XqMove(4, 5, 8, 5))));
    });
  });

  group('horse (马)', () {
    test('has all 8 L-shaped moves from an open center', () {
      final b = emptyBoard()..squares[5][4] = const XqPiece(PieceType.horse, Side.red);
      final moves = b.pseudoLegalMovesFrom(4, 5).toSet();
      expect(moves.length, 8);
    });

    test('蹩马腿: a piece on the leg square blocks that direction', () {
      final b = emptyBoard()
        ..squares[5][4] = const XqPiece(PieceType.horse, Side.red)
        ..squares[4][4] = const XqPiece(PieceType.soldier, Side.red); // blocks the (dy=-2) leg
      final moves = b.pseudoLegalMovesFrom(4, 5).toSet();
      expect(moves, isNot(contains(const XqMove(4, 5, 5, 3))));
      expect(moves, isNot(contains(const XqMove(4, 5, 3, 3))));
      // Unaffected directions still work.
      expect(moves, contains(const XqMove(4, 5, 5, 7)));
    });
  });

  group('elephant (象/相)', () {
    test('塞象眼: blocked if the diagonal midpoint is occupied', () {
      final b = emptyBoard()
        ..squares[2][2] = const XqPiece(PieceType.elephant, Side.red)
        ..squares[3][3] = const XqPiece(PieceType.soldier, Side.red);
      final moves = b.pseudoLegalMovesFrom(2, 2).toSet();
      expect(moves, isNot(contains(const XqMove(2, 2, 4, 4))));
    });

    test('cannot cross the river', () {
      final b = emptyBoard()..squares[4][2] = const XqPiece(PieceType.elephant, Side.red);
      final moves = b.pseudoLegalMovesFrom(2, 4).toSet();
      expect(moves, isNot(contains(const XqMove(2, 4, 4, 6))));
      expect(moves, contains(const XqMove(2, 4, 4, 2)));
    });
  });

  group('advisor (士/仕)', () {
    test('stays within the palace', () {
      final b = emptyBoard()..squares[0][3] = const XqPiece(PieceType.advisor, Side.red);
      final moves = b.pseudoLegalMovesFrom(3, 0).toSet();
      expect(moves, equals({const XqMove(3, 0, 4, 1)}));
    });
  });

  group('king/general (帅/将)', () {
    test('one step orthogonally, stays within the palace', () {
      final b = emptyBoard()..squares[0][4] = const XqPiece(PieceType.king, Side.red);
      final moves = b.pseudoLegalMovesFrom(4, 0).toSet();
      expect(moves, containsAll([
        const XqMove(4, 0, 3, 0),
        const XqMove(4, 0, 5, 0),
        const XqMove(4, 0, 4, 1),
      ]));
      expect(moves.length, 3); // can't leave the palace downward (off board) either
    });

    test('flying general: kings facing on an open file is illegal', () {
      final b = emptyBoard()
        ..squares[0][4] = const XqPiece(PieceType.king, Side.red)
        ..squares[9][4] = const XqPiece(PieceType.king, Side.black)
        ..squares[5][4] = const XqPiece(PieceType.chariot, Side.red); // blocks the file
      // Moving the blocking chariot away exposes the generals to each other.
      final legal = b.legalMovesFrom(4, 5);
      expect(legal, isNot(contains(const XqMove(4, 5, 0, 5))));
    });
  });

  group('soldier/pawn (兵/卒)', () {
    test('before crossing the river: forward only, no sideways', () {
      final b = emptyBoard()..squares[3][4] = const XqPiece(PieceType.soldier, Side.red);
      final moves = b.pseudoLegalMovesFrom(4, 3).toSet();
      expect(moves, equals({const XqMove(4, 3, 4, 4)}));
    });

    test('after crossing the river: forward and sideways, never backward', () {
      final b = emptyBoard()..squares[5][4] = const XqPiece(PieceType.soldier, Side.red);
      final moves = b.pseudoLegalMovesFrom(4, 5).toSet();
      expect(moves, containsAll([
        const XqMove(4, 5, 4, 6),
        const XqMove(4, 5, 3, 5),
        const XqMove(4, 5, 5, 5),
      ]));
      expect(moves, isNot(contains(const XqMove(4, 5, 4, 4)))); // no backward
      expect(moves.length, 3);
    });

    test('black soldiers move toward decreasing y', () {
      final b = emptyBoard()..squares[6][4] = const XqPiece(PieceType.soldier, Side.black);
      final moves = b.pseudoLegalMovesFrom(4, 6).toSet();
      expect(moves, equals({const XqMove(4, 6, 4, 5)}));
    });
  });

  group('check / checkmate / legality filtering', () {
    test('a move that leaves your own king in check is illegal', () {
      // Black chariot checks red's king along the open file x=4. A red
      // soldier off to the side has a pseudo-legal move that does nothing
      // to address that check, so it must be filtered out even though the
      // move itself is otherwise unobstructed.
      final b = emptyBoard()
        ..squares[0][4] = const XqPiece(PieceType.king, Side.red)
        ..squares[9][4] = const XqPiece(PieceType.king, Side.black)
        ..squares[5][4] = const XqPiece(PieceType.chariot, Side.black)
        ..squares[3][0] = const XqPiece(PieceType.soldier, Side.red);
      expect(b.isInCheck(Side.red), isTrue);
      expect(b.legalMovesFrom(0, 3), isEmpty);
    });

    test('checkmate: king in check with no legal response', () {
      // Red king cornered at (3,0): its only two palace-adjacent squares
      // are (4,0) and (3,1). One black chariot checks straight down file 3
      // (also covering (3,1) along the way); a second checks along rank 0
      // from the far side (also covering (4,0) along the way). No red piece
      // besides the king exists to block or capture either one.
      final b = emptyBoard()
        ..squares[0][3] = const XqPiece(PieceType.king, Side.red)
        ..squares[5][3] = const XqPiece(PieceType.chariot, Side.black)
        ..squares[0][8] = const XqPiece(PieceType.chariot, Side.black);
      expect(b.isInCheck(Side.red), isTrue);
      expect(b.isCheckmate, isTrue);
    });

    test('a fully boxed-in side with no check is stalemate (a loss in Xiangqi)', () {
      // Red king at (4,0), not currently attacked. Its three escape
      // squares are each covered without ever attacking (4,0) itself:
      // chariots pin the two file-adjacent squares (3,0)/(5,0) from
      // straight down their own files, and a horse (whose attack pattern
      // skips (4,0) entirely) covers (4,1).
      final b = emptyBoard(sideToMove: Side.red)
        ..squares[0][4] = const XqPiece(PieceType.king, Side.red)
        ..squares[5][3] = const XqPiece(PieceType.chariot, Side.black)
        ..squares[5][5] = const XqPiece(PieceType.chariot, Side.black)
        ..squares[2][2] = const XqPiece(PieceType.horse, Side.black);
      expect(b.isInCheck(Side.red), isFalse);
      expect(b.hasNoLegalMoves, isTrue);
      expect(b.isStalemate, isTrue);
    });
  });

  group('applyMove', () {
    test('moves the piece, captures, and flips the side to move', () {
      final b = emptyBoard()
        ..squares[5][4] = const XqPiece(PieceType.chariot, Side.red)
        ..squares[5][7] = const XqPiece(PieceType.soldier, Side.black);
      final captured = b.applyMove(const XqMove(4, 5, 7, 5));
      expect(captured, const XqPiece(PieceType.soldier, Side.black));
      expect(b.at(7, 5), const XqPiece(PieceType.chariot, Side.red));
      expect(b.at(4, 5), isNull);
      expect(b.sideToMove, Side.black);
    });
  });
}
