/// Red always moves first (matches Pikafish's UCI convention, where Red is
/// "white"/uppercase FEN letters and Black is "black"/lowercase).
enum Side {
  red,
  black;

  Side get opponent => this == Side.red ? Side.black : Side.red;
}

enum PieceType {
  king, // 帅/将
  advisor, // 仕/士
  elephant, // 相/象
  horse, // 马
  chariot, // 车
  cannon, // 炮
  soldier; // 兵/卒

  /// FEN/UCI letter for this piece (case carries the side separately).
  String get letter => switch (this) {
        PieceType.king => 'k',
        PieceType.advisor => 'a',
        PieceType.elephant => 'b',
        PieceType.horse => 'n',
        PieceType.chariot => 'r',
        PieceType.cannon => 'c',
        PieceType.soldier => 'p',
      };

  static PieceType? fromLetter(String letter) => switch (letter.toLowerCase()) {
        'k' => PieceType.king,
        'a' => PieceType.advisor,
        'b' => PieceType.elephant,
        'n' => PieceType.horse,
        'r' => PieceType.chariot,
        'c' => PieceType.cannon,
        'p' => PieceType.soldier,
        _ => null,
      };
}

class XqPiece {
  const XqPiece(this.type, this.side);

  final PieceType type;
  final Side side;

  /// FEN letter: uppercase for Red, lowercase for Black.
  String get fenChar =>
      side == Side.red ? type.letter.toUpperCase() : type.letter;

  @override
  bool operator ==(Object other) =>
      other is XqPiece && other.type == type && other.side == side;

  @override
  int get hashCode => Object.hash(type, side);

  @override
  String toString() => '${side.name} ${type.name}';
}
