import 'fen.dart';
import 'piece.dart';
import 'xq_move.dart';

/// Full Xiangqi rules: legal move generation (including check and the
/// "flying general" restriction), check/checkmate/stalemate detection, and
/// FEN round-tripping. Pure game logic — no engine, no UI.
///
/// Board coordinates match Pikafish's own UCI numbering: `x` is the file
/// (0-8, a-i), `y` is the rank (0-9); rank 0 is Red's back rank, rank 9 is
/// Black's. `squares[y][x]` is the piece at that intersection, or `null`.
class XiangqiBoard {
  XiangqiBoard({required this.squares, this.sideToMove = Side.red});

  factory XiangqiBoard.startPosition() => XiangqiBoard.fromFen(xiangqiStartFen);

  factory XiangqiBoard.fromFen(String fen) {
    final (squares, side) = parseXiangqiFen(fen);
    return XiangqiBoard(squares: squares, sideToMove: side);
  }

  final List<List<XqPiece?>> squares;
  Side sideToMove;

  String toFenFields() => boardToFenFields(squares, sideToMove);

  XiangqiBoard clone() => XiangqiBoard(
        squares: [for (final row in squares) List<XqPiece?>.from(row)],
        sideToMove: sideToMove,
      );

  static bool inBounds(int x, int y) => x >= 0 && x < xqFiles && y >= 0 && y < xqRanks;

  XqPiece? at(int x, int y) => inBounds(x, y) ? squares[y][x] : null;

  static bool _isPalaceFile(int x) => x >= 3 && x <= 5;
  static bool isRedPalace(int x, int y) => _isPalaceFile(x) && y >= 0 && y <= 2;
  static bool isBlackPalace(int x, int y) => _isPalaceFile(x) && y >= 7 && y <= 9;
  static bool isPalace(int x, int y, Side side) =>
      side == Side.red ? isRedPalace(x, y) : isBlackPalace(x, y);

  /// Whether `y` is on [side]'s own half of the board (hasn't crossed the
  /// river from that side's point of view).
  static bool isOwnSide(int y, Side side) => side == Side.red ? y <= 4 : y >= 5;

  (int, int)? kingSquare(Side side) {
    for (var y = 0; y < xqRanks; y++) {
      for (var x = 0; x < xqFiles; x++) {
        final p = squares[y][x];
        if (p != null && p.type == PieceType.king && p.side == side) return (x, y);
      }
    }
    return null;
  }

  /// The two generals directly facing each other on an open file — always
  /// illegal in Xiangqi, checked in addition to ordinary check.
  bool generalsFacing() {
    final red = kingSquare(Side.red);
    final black = kingSquare(Side.black);
    if (red == null || black == null || red.$1 != black.$1) return false;
    final x = red.$1;
    final lowY = red.$2 < black.$2 ? red.$2 : black.$2;
    final highY = red.$2 < black.$2 ? black.$2 : red.$2;
    for (var y = lowY + 1; y < highY; y++) {
      if (squares[y][x] != null) return false;
    }
    return true;
  }

  bool isSquareAttackedBy(int x, int y, Side attacker) {
    for (var py = 0; py < xqRanks; py++) {
      for (var px = 0; px < xqFiles; px++) {
        final p = squares[py][px];
        if (p == null || p.side != attacker) continue;
        if (_pseudoLegalDestinationsFrom(px, py, p).any((m) => m.toX == x && m.toY == y)) {
          return true;
        }
      }
    }
    return false;
  }

  bool isInCheck(Side side) {
    final king = kingSquare(side);
    if (king == null) return false;
    return isSquareAttackedBy(king.$1, king.$2, side.opponent);
  }

  /// Movement-pattern + blocking only — does not check for self-check or
  /// the flying-general rule (see [legalMovesFrom] for that).
  List<XqMove> pseudoLegalMovesFrom(int x, int y) {
    final piece = at(x, y);
    if (piece == null) return const [];
    return _pseudoLegalDestinationsFrom(x, y, piece);
  }

  List<XqMove> _pseudoLegalDestinationsFrom(int x, int y, XqPiece piece) {
    return switch (piece.type) {
      PieceType.chariot => _slidingMoves(x, y, piece.side, _orthogonalDirs),
      PieceType.cannon => _cannonMoves(x, y, piece.side),
      PieceType.horse => _horseMoves(x, y, piece.side),
      PieceType.elephant => _elephantMoves(x, y, piece.side),
      PieceType.advisor => _advisorMoves(x, y, piece.side),
      PieceType.king => _kingMoves(x, y, piece.side),
      PieceType.soldier => _soldierMoves(x, y, piece.side),
    };
  }

  static const _orthogonalDirs = [(1, 0), (-1, 0), (0, 1), (0, -1)];
  static const _diagonalDirs = [(1, 1), (1, -1), (-1, 1), (-1, -1)];

  bool _canLandOn(int x, int y, Side mover) {
    if (!inBounds(x, y)) return false;
    final occupant = squares[y][x];
    return occupant == null || occupant.side != mover;
  }

  List<XqMove> _slidingMoves(int x, int y, Side mover, List<(int, int)> dirs) {
    final moves = <XqMove>[];
    for (final (dx, dy) in dirs) {
      var nx = x + dx, ny = y + dy;
      while (inBounds(nx, ny)) {
        final occupant = squares[ny][nx];
        if (occupant == null) {
          moves.add(XqMove(x, y, nx, ny));
        } else {
          if (occupant.side != mover) moves.add(XqMove(x, y, nx, ny));
          break;
        }
        nx += dx;
        ny += dy;
      }
    }
    return moves;
  }

  List<XqMove> _cannonMoves(int x, int y, Side mover) {
    final moves = <XqMove>[];
    for (final (dx, dy) in _orthogonalDirs) {
      var nx = x + dx, ny = y + dy;
      // Phase 1: quiet moves along empty squares up to (not incl.) the screen.
      while (inBounds(nx, ny) && squares[ny][nx] == null) {
        moves.add(XqMove(x, y, nx, ny));
        nx += dx;
        ny += dy;
      }
      if (!inBounds(nx, ny)) continue; // ran off the board, no screen found
      // nx,ny is the screen. Keep stepping past it for a capture.
      nx += dx;
      ny += dy;
      while (inBounds(nx, ny) && squares[ny][nx] == null) {
        nx += dx;
        ny += dy;
      }
      if (inBounds(nx, ny) && squares[ny][nx]!.side != mover) {
        moves.add(XqMove(x, y, nx, ny));
      }
    }
    return moves;
  }

  static const _horseOffsets = [
    (1, 2, 0, 1), (-1, 2, 0, 1), (1, -2, 0, -1), (-1, -2, 0, -1),
    (2, 1, 1, 0), (2, -1, 1, 0), (-2, 1, -1, 0), (-2, -1, -1, 0),
  ];

  List<XqMove> _horseMoves(int x, int y, Side mover) {
    final moves = <XqMove>[];
    for (final (dx, dy, legDx, legDy) in _horseOffsets) {
      if (at(x + legDx, y + legDy) != null) continue; // 蹩马腿
      final nx = x + dx, ny = y + dy;
      if (_canLandOn(nx, ny, mover)) moves.add(XqMove(x, y, nx, ny));
    }
    return moves;
  }

  List<XqMove> _elephantMoves(int x, int y, Side mover) {
    final moves = <XqMove>[];
    for (final (dx, dy) in _diagonalDirs) {
      // The "eye" (blocking point) is the single diagonal step; the
      // destination is two diagonal steps out.
      final eyeX = x + dx, eyeY = y + dy;
      final nx = x + 2 * dx, ny = y + 2 * dy;
      if (at(eyeX, eyeY) != null) continue; // 塞象眼
      if (!isOwnSide(ny, mover)) continue; // can't cross the river
      if (_canLandOn(nx, ny, mover)) moves.add(XqMove(x, y, nx, ny));
    }
    return moves;
  }

  List<XqMove> _advisorMoves(int x, int y, Side mover) {
    final moves = <XqMove>[];
    for (final (dx, dy) in _diagonalDirs) {
      final nx = x + dx, ny = y + dy;
      if (!isPalace(nx, ny, mover)) continue;
      if (_canLandOn(nx, ny, mover)) moves.add(XqMove(x, y, nx, ny));
    }
    return moves;
  }

  List<XqMove> _kingMoves(int x, int y, Side mover) {
    final moves = <XqMove>[];
    for (final (dx, dy) in _orthogonalDirs) {
      final nx = x + dx, ny = y + dy;
      if (!isPalace(nx, ny, mover)) continue;
      if (_canLandOn(nx, ny, mover)) moves.add(XqMove(x, y, nx, ny));
    }
    return moves;
  }

  List<XqMove> _soldierMoves(int x, int y, Side mover) {
    final moves = <XqMove>[];
    final forwardY = y + (mover == Side.red ? 1 : -1);
    if (_canLandOn(x, forwardY, mover)) moves.add(XqMove(x, y, x, forwardY));
    if (!isOwnSide(y, mover)) {
      // Crossed the river: can also step sideways.
      for (final dx in [-1, 1]) {
        final nx = x + dx;
        if (_canLandOn(nx, y, mover)) moves.add(XqMove(x, y, nx, y));
      }
    }
    return moves;
  }

  /// Pseudo-legal moves filtered to ones that don't leave the mover's own
  /// king in check and don't create a flying-general facing position.
  List<XqMove> legalMovesFrom(int x, int y) {
    final piece = at(x, y);
    if (piece == null) return const [];
    return pseudoLegalMovesFrom(x, y).where((m) => _isSafe(m, piece.side)).toList();
  }

  List<XqMove> legalMoves(Side side) {
    final moves = <XqMove>[];
    for (var y = 0; y < xqRanks; y++) {
      for (var x = 0; x < xqFiles; x++) {
        final p = squares[y][x];
        if (p != null && p.side == side) moves.addAll(legalMovesFrom(x, y));
      }
    }
    return moves;
  }

  bool _isSafe(XqMove move, Side mover) {
    final clone = this.clone();
    clone.applyMove(move);
    return !clone.isInCheck(mover) && !clone.generalsFacing();
  }

  bool get isCheckmate => isInCheck(sideToMove) && legalMoves(sideToMove).isEmpty;

  /// Xiangqi has no drawn stalemate: being unable to move at all is a loss
  /// for the side to move (困毙), same severity as checkmate. Exposed
  /// separately so callers can tell the two apart for display purposes.
  bool get isStalemate => !isInCheck(sideToMove) && legalMoves(sideToMove).isEmpty;

  bool get hasNoLegalMoves => legalMoves(sideToMove).isEmpty;

  /// Applies [move] (assumed legal), flips [sideToMove], and returns the
  /// captured piece if any.
  XqPiece? applyMove(XqMove move) {
    final mover = squares[move.fromY][move.fromX];
    final captured = squares[move.toY][move.toX];
    squares[move.toY][move.toX] = mover;
    squares[move.fromY][move.fromX] = null;
    sideToMove = sideToMove.opponent;
    return captured;
  }
}
