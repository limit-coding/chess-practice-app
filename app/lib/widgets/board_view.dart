import 'package:flutter/material.dart';

import '../game/stone.dart';

/// A square 15×15 (or [boardSize]) Gomoku board. Intersection `(x, y)` sits
/// at the center of cell `(x, y)` in an evenly divided `boardSize ×
/// boardSize` grid — [localToCell] and the painter's intersection math must
/// stay in sync so a tap always lands on the intersection it visually points
/// at.
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.boardSize,
    required this.board,
    this.lastMove,
    this.winningLine = const [],
    this.onTapCell,
  });

  final int boardSize;
  final List<List<Stone?>> board;
  final (int, int)? lastMove;
  final List<(int, int)> winningLine;
  final void Function(int x, int y)? onTapCell;

  /// Maps a tap position within a board of [side] logical pixels to the
  /// nearest board cell, clamped to the valid range.
  (int, int) localToCell(Offset local, double side) {
    final cell = side / boardSize;
    final x = (local.dx / cell).floor().clamp(0, boardSize - 1);
    final y = (local.dy / cell).floor().clamp(0, boardSize - 1);
    return (x, y);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        return GestureDetector(
          onTapUp: onTapCell == null
              ? null
              : (details) {
                  final (x, y) = localToCell(details.localPosition, side);
                  onTapCell!(x, y);
                },
          child: SizedBox(
            width: side,
            height: side,
            child: CustomPaint(
              painter: _BoardPainter(
                boardSize: boardSize,
                board: board,
                lastMove: lastMove,
                winningLine: winningLine,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.boardSize,
    required this.board,
    required this.lastMove,
    required this.winningLine,
  });

  final int boardSize;
  final List<List<Stone?>> board;
  final (int, int)? lastMove;
  final List<(int, int)> winningLine;

  static const _boardColor = Color(0xFFDCB35C);
  static const _lineColor = Color(0xFF3E2A15);

  Offset _center(int x, int y, double cell) =>
      Offset((x + 0.5) * cell, (y + 0.5) * cell);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / boardSize;

    canvas.drawRect(Offset.zero & size, Paint()..color = _boardColor);

    final linePaint = Paint()
      ..color = _lineColor
      ..strokeWidth = 1;
    for (var i = 0; i < boardSize; i++) {
      final start = _center(i, 0, cell);
      final end = _center(i, boardSize - 1, cell);
      canvas.drawLine(start, end, linePaint); // vertical
      canvas.drawLine(
        _center(0, i, cell),
        _center(boardSize - 1, i, cell),
        linePaint,
      ); // horizontal
    }

    final winSet = winningLine.toSet();
    final stoneRadius = cell * 0.42;
    for (var y = 0; y < boardSize; y++) {
      for (var x = 0; x < boardSize; x++) {
        final stone = board[y][x];
        if (stone == null) continue;
        final center = _center(x, y, cell);
        canvas.drawCircle(
          center,
          stoneRadius,
          Paint()..color = stone == Stone.black ? Colors.black : Colors.white,
        );
        if (stone == Stone.white) {
          canvas.drawCircle(
            center,
            stoneRadius,
            Paint()
              ..color = Colors.black54
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
        if (winSet.contains((x, y))) {
          canvas.drawCircle(
            center,
            stoneRadius * 0.5,
            Paint()..color = Colors.redAccent,
          );
        }
      }
    }

    if (lastMove != null) {
      final (x, y) = lastMove!;
      canvas.drawCircle(
        _center(x, y, cell),
        stoneRadius * 0.28,
        Paint()..color = Colors.redAccent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) {
    return oldDelegate.board != board ||
        oldDelegate.lastMove != lastMove ||
        oldDelegate.winningLine != winningLine;
  }
}
