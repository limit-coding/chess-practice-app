/// One Xiangqi move, in the engine's own 0-indexed coordinates: file 0-8
/// (a-i), rank 0-9 — unlike Gomoku/chess, Pikafish's UCI ranks are *not*
/// 1-indexed (verified against real engine output: "h2e2", "c3c4", ...).
class XqMove {
  const XqMove(this.fromX, this.fromY, this.toX, this.toY);

  final int fromX;
  final int fromY;
  final int toX;
  final int toY;

  /// UCI move notation, e.g. "h2e2".
  String get uci =>
      '${_fileChar(fromX)}$fromY${_fileChar(toX)}$toY';

  static String _fileChar(int x) => String.fromCharCode('a'.codeUnitAt(0) + x);

  /// Parses a 4-character UCI move like "h2e2". Returns `null` if
  /// malformed.
  static XqMove? fromUci(String uci) {
    if (uci.length != 4) return null;
    final fx = _fileFromChar(uci[0]);
    final fy = int.tryParse(uci[1]);
    final tx = _fileFromChar(uci[2]);
    final ty = int.tryParse(uci[3]);
    if (fx == null || fy == null || tx == null || ty == null) return null;
    return XqMove(fx, fy, tx, ty);
  }

  static int? _fileFromChar(String c) {
    final code = c.toLowerCase().codeUnitAt(0);
    final x = code - 'a'.codeUnitAt(0);
    return (x >= 0 && x < 9) ? x : null;
  }

  @override
  bool operator ==(Object other) =>
      other is XqMove &&
      other.fromX == fromX &&
      other.fromY == fromY &&
      other.toX == toX &&
      other.toY == toY;

  @override
  int get hashCode => Object.hash(fromX, fromY, toX, toY);

  @override
  String toString() => uci;
}
