import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../xiangqi/fen.dart';
import '../xiangqi/piece.dart';
import '../xiangqi/xq_move.dart';

/// A 9×10 Xiangqi board. Red's side (`y` 0-4) renders at the bottom, Black's
/// (`y` 5-9) at the top — canvas `y` increases downward, so painting flips
/// [XiangqiBoard]'s own `y` (which increases from Red's back rank upward).
///
/// Interaction is select-then-move (tap your own piece, then tap a
/// destination) rather than Gomoku's single-tap-to-place, so the caller
/// drives [selected]/[legalDestinations] and just gets told which cell was
/// tapped.
class XiangqiBoardView extends StatelessWidget {
  const XiangqiBoardView({
    super.key,
    required this.squares,
    this.selected,
    this.legalDestinations = const [],
    this.lastMove,
    this.hintMove,
    this.onTapCell,
  });

  final List<List<XqPiece?>> squares;
  final (int, int)? selected;
  final List<(int, int)> legalDestinations;
  final (int, int)? lastMove;

  /// Drawn as dashed "ghost" rings on the from/to squares — review's way of
  /// pointing at an engine-recommended move (see BoardView.hintMove for the
  /// Gomoku equivalent).
  final XqMove? hintMove;
  final void Function(int x, int y)? onTapCell;

  /// Maps a tap position within a board of [width]x[height] logical pixels
  /// to the nearest board cell, clamped to the valid range.
  (int, int) localToCell(Offset local, double width, double height) {
    final cellW = width / xqFiles;
    final cellH = height / xqRanks;
    final x = (local.dx / cellW).floor().clamp(0, xqFiles - 1);
    final screenRow = (local.dy / cellH).floor().clamp(0, xqRanks - 1);
    return (x, xqRanks - 1 - screenRow);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Xiangqi boards are wider than tall (9 files x 10 ranks worth of
        // cells, roughly square cells) — fit within the available box.
        final cellSize = (constraints.maxWidth / xqFiles)
            .clamp(0, constraints.maxHeight / xqRanks)
            .toDouble();
        final width = cellSize * xqFiles;
        final height = cellSize * xqRanks;
        return GestureDetector(
          onTapUp: onTapCell == null
              ? null
              : (details) {
                  final (x, y) = localToCell(details.localPosition, width, height);
                  onTapCell!(x, y);
                },
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(
              painter: _XiangqiBoardPainter(
                squares: squares,
                selected: selected,
                legalDestinations: legalDestinations,
                lastMove: lastMove,
                hintMove: hintMove,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _XiangqiBoardPainter extends CustomPainter {
  _XiangqiBoardPainter({
    required this.squares,
    required this.selected,
    required this.legalDestinations,
    required this.lastMove,
    required this.hintMove,
  });

  final List<List<XqPiece?>> squares;
  final (int, int)? selected;
  final List<(int, int)> legalDestinations;
  final (int, int)? lastMove;
  final XqMove? hintMove;

  static const _boardColor = Color(0xFFE8CE9A);
  static const _lineColor = Color(0xFF3E2A15);

  /// Screen position for board coordinate (x, y) — y flips so Red's rank 0
  /// renders at the bottom.
  Offset _pos(int x, int y, double cell) =>
      Offset((x + 0.5) * cell, (xqRanks - 1 - y + 0.5) * cell);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / xqFiles;
    canvas.drawRect(Offset.zero & size, Paint()..color = _boardColor);

    final linePaint = Paint()
      ..color = _lineColor
      ..strokeWidth = 1;

    // Vertical file lines: full height except they stop at the river for
    // the middle files (1-7) — visually just draw them full height with a
    // gap; simplest correct rendering is two segments per file except the
    // two edge files.
    for (var x = 0; x < xqFiles; x++) {
      if (x == 0 || x == xqFiles - 1) {
        canvas.drawLine(_pos(x, 0, cell), _pos(x, xqRanks - 1, cell), linePaint);
      } else {
        canvas.drawLine(_pos(x, 0, cell), _pos(x, 4, cell), linePaint);
        canvas.drawLine(_pos(x, 5, cell), _pos(x, xqRanks - 1, cell), linePaint);
      }
    }
    for (var y = 0; y < xqRanks; y++) {
      canvas.drawLine(_pos(0, y, cell), _pos(xqFiles - 1, y, cell), linePaint);
    }

    // Palace diagonals (both sides).
    canvas.drawLine(_pos(3, 0, cell), _pos(5, 2, cell), linePaint);
    canvas.drawLine(_pos(5, 0, cell), _pos(3, 2, cell), linePaint);
    canvas.drawLine(_pos(3, 9, cell), _pos(5, 7, cell), linePaint);
    canvas.drawLine(_pos(5, 9, cell), _pos(3, 7, cell), linePaint);

    // River label.
    final riverText = TextPainter(
      text: const TextSpan(
        text: '楚 河                汉 界',
        style: TextStyle(color: _lineColor, fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    riverText.paint(
      canvas,
      Offset((size.width - riverText.width) / 2, (_pos(0, 4, cell).dy + _pos(0, 5, cell).dy) / 2 - riverText.height / 2),
    );

    // Legal-destination markers (drawn under pieces).
    for (final (x, y) in legalDestinations) {
      canvas.drawCircle(
        _pos(x, y, cell),
        cell * 0.12,
        Paint()..color = Colors.green.withValues(alpha: 0.6),
      );
    }

    // Pieces.
    final pieceRadius = cell * 0.42;
    for (var y = 0; y < xqRanks; y++) {
      for (var x = 0; x < xqFiles; x++) {
        final piece = squares[y][x];
        if (piece == null) continue;
        final center = _pos(x, y, cell);
        final isSelected = selected == (x, y);

        canvas.drawCircle(center, pieceRadius, Paint()..color = const Color(0xFFF3E3C3));
        canvas.drawCircle(
          center,
          pieceRadius,
          Paint()
            ..color = piece.side == Side.red ? Colors.red.shade700 : Colors.black87
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? 3 : 1.5,
        );

        final textPainter = TextPainter(
          text: TextSpan(
            text: _label(piece),
            style: TextStyle(
              color: piece.side == Side.red ? Colors.red.shade700 : Colors.black87,
              fontSize: pieceRadius,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          center - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }
    }

    if (lastMove != null) {
      canvas.drawCircle(
        _pos(lastMove!.$1, lastMove!.$2, cell),
        pieceRadius * 0.25,
        Paint()..color = Colors.blueAccent,
      );
    }

    if (hintMove != null) {
      final dashPaint = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      _drawDashedCircle(canvas, _pos(hintMove!.fromX, hintMove!.fromY, cell), pieceRadius, dashPaint);
      _drawDashedCircle(canvas, _pos(hintMove!.toX, hintMove!.toY, cell), pieceRadius, dashPaint);
    }
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const dashCount = 14;
    const dashFraction = 0.6;
    const anglePerDash = 2 * math.pi / dashCount;
    final sweep = anglePerDash * dashFraction;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(rect, i * anglePerDash, sweep, false, paint);
    }
  }

  static String _label(XqPiece piece) {
    final red = piece.side == Side.red;
    return switch (piece.type) {
      PieceType.king => red ? '帅' : '将',
      PieceType.advisor => red ? '仕' : '士',
      PieceType.elephant => red ? '相' : '象',
      PieceType.horse => '马',
      PieceType.chariot => '车',
      PieceType.cannon => '炮',
      PieceType.soldier => red ? '兵' : '卒',
    };
  }

  @override
  bool shouldRepaint(covariant _XiangqiBoardPainter oldDelegate) {
    return oldDelegate.squares != squares ||
        oldDelegate.selected != selected ||
        oldDelegate.legalDestinations != legalDestinations ||
        oldDelegate.lastMove != lastMove ||
        oldDelegate.hintMove != hintMove;
  }
}
