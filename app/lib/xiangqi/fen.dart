import 'piece.dart';

/// Pikafish's starting position (src/uci.h `StartFEN`).
const String xiangqiStartFen =
    'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1';

const int xqFiles = 9;
const int xqRanks = 10;

/// Parses the board part of a Xiangqi FEN (plus the side-to-move field) into
/// a `[y][x]` grid, `y` and `x` both 0-indexed matching Pikafish's own UCI
/// square numbering (rank 0 = Red's back rank). Only the piece placement and
/// active-color fields are used — halfmove/fullmove counters and the (in
/// Xiangqi, always empty) castling/en-passant fields are ignored.
(List<List<XqPiece?>>, Side) parseXiangqiFen(String fen) {
  final parts = fen.trim().split(RegExp(r'\s+'));
  final boardPart = parts[0];
  final sideToMove = (parts.length > 1 && parts[1] == 'b') ? Side.black : Side.red;

  final rows = boardPart.split('/');
  assert(rows.length == xqRanks, 'FEN must have $xqRanks ranks, got ${rows.length}');

  final squares = List.generate(xqRanks, (_) => List<XqPiece?>.filled(xqFiles, null));
  for (var rowIdx = 0; rowIdx < rows.length; rowIdx++) {
    // FEN rows go from rank (xqRanks-1) down to rank 0.
    final y = xqRanks - 1 - rowIdx;
    var x = 0;
    for (final char in rows[rowIdx].split('')) {
      final digit = int.tryParse(char);
      if (digit != null) {
        x += digit;
        continue;
      }
      final type = PieceType.fromLetter(char);
      if (type == null) continue;
      final side = char == char.toUpperCase() ? Side.red : Side.black;
      if (x < xqFiles) squares[y][x] = XqPiece(type, side);
      x++;
    }
  }

  return (squares, sideToMove);
}

/// Serializes a board back to the FEN piece-placement + side-to-move
/// fields (e.g. `"...RNBAKABNR w"`) — halfmove/fullmove counters aren't
/// tracked by [XiangqiBoard], so callers needing a full FEN (for the
/// engine's `position fen ...`) append `- - 0 1` themselves.
String boardToFenFields(List<List<XqPiece?>> squares, Side sideToMove) {
  final rows = <String>[];
  for (var y = xqRanks - 1; y >= 0; y--) {
    final buf = StringBuffer();
    var empty = 0;
    for (var x = 0; x < xqFiles; x++) {
      final piece = squares[y][x];
      if (piece == null) {
        empty++;
        continue;
      }
      if (empty > 0) {
        buf.write(empty);
        empty = 0;
      }
      buf.write(piece.fenChar);
    }
    if (empty > 0) buf.write(empty);
    rows.add(buf.toString());
  }
  return '${rows.join('/')} ${sideToMove == Side.red ? 'w' : 'b'}';
}
