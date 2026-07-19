import 'stone.dart';

/// One played move: who, where, and when.
class MoveRecord {
  const MoveRecord({
    required this.stone,
    required this.x,
    required this.y,
    required this.timestamp,
  });

  final Stone stone;
  final int x;
  final int y;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'stone': stone.name,
        'x': x,
        'y': y,
        'timestamp': timestamp.toIso8601String(),
      };

  factory MoveRecord.fromJson(Map<String, dynamic> json) => MoveRecord(
        stone: Stone.values.byName(json['stone'] as String),
        x: json['x'] as int,
        y: json['y'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
