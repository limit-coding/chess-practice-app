import 'package:flutter/material.dart';

/// A per-ply bar chart of a game's score curve (see
/// `GameReview.blackPovCurve`): positive bars favor Black (the human),
/// negative bars favor White (the engine). Tapping a bar selects that ply.
class ScoreCurve extends StatelessWidget {
  const ScoreCurve({
    super.key,
    required this.curve,
    this.selectedPly,
    this.onSelectPly,
    this.height = 80,
  });

  /// One entry per position (`curve.length == moves.length + 1`); `null`
  /// where that position's evaluation is missing.
  final List<int?> curve;
  final int? selectedPly;
  final ValueChanged<int>? onSelectPly;
  final double height;

  static const _clamp = 1000; // display range in engine eval units

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          onTapUp: onSelectPly == null
              ? null
              : (details) {
                  final barWidth = width / curve.length;
                  final ply = (details.localPosition.dx / barWidth)
                      .floor()
                      .clamp(0, curve.length - 1);
                  onSelectPly!(ply);
                },
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(
              painter: _ScoreCurvePainter(
                curve: curve,
                selectedPly: selectedPly,
                clamp: _clamp,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScoreCurvePainter extends CustomPainter {
  _ScoreCurvePainter({
    required this.curve,
    required this.selectedPly,
    required this.clamp,
  });

  final List<int?> curve;
  final int? selectedPly;
  final int clamp;

  @override
  void paint(Canvas canvas, Size size) {
    if (curve.isEmpty) return;
    final barWidth = size.width / curve.length;
    final midY = size.height / 2;

    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      Paint()
        ..color = Colors.black26
        ..strokeWidth = 1,
    );

    for (var i = 0; i < curve.length; i++) {
      final value = curve[i];
      final left = i * barWidth;
      final isSelected = i == selectedPly;

      if (value == null) {
        canvas.drawRect(
          Rect.fromLTWH(left, midY - 1, barWidth, 2),
          Paint()..color = Colors.grey.shade300,
        );
        continue;
      }

      final magnitude = (value.abs() / clamp).clamp(0.0, 1.0) * midY;
      final rect = value >= 0
          ? Rect.fromLTWH(left, midY - magnitude, barWidth, magnitude)
          : Rect.fromLTWH(left, midY, barWidth, magnitude);

      canvas.drawRect(
        rect,
        Paint()
          ..color = value >= 0
              ? (isSelected ? Colors.brown.shade900 : Colors.brown.shade400)
              : (isSelected ? Colors.grey.shade900 : Colors.grey.shade500),
      );
    }

    if (selectedPly != null) {
      final x = (selectedPly! + 0.5) * barWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = Colors.redAccent
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreCurvePainter oldDelegate) {
    return oldDelegate.curve != curve || oldDelegate.selectedPly != selectedPly;
  }
}
