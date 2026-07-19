import 'piece.dart';

/// One played Xiangqi move: who, from/to, and when — the Xiangqi analogue
/// of Gomoku's MoveRecord (see game/move_record.dart).
class XqMoveRecord {
  const XqMoveRecord({
    required this.side,
    required this.fromX,
    required this.fromY,
    required this.toX,
    required this.toY,
    required this.timestamp,
  });

  final Side side;
  final int fromX;
  final int fromY;
  final int toX;
  final int toY;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'side': side.name,
        'fromX': fromX,
        'fromY': fromY,
        'toX': toX,
        'toY': toY,
        'timestamp': timestamp.toIso8601String(),
      };

  factory XqMoveRecord.fromJson(Map<String, dynamic> json) => XqMoveRecord(
        side: Side.values.byName(json['side'] as String),
        fromX: json['fromX'] as int,
        fromY: json['fromY'] as int,
        toX: json['toX'] as int,
        toY: json['toY'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
