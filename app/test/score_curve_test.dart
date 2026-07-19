import 'package:chess_practice/widgets/score_curve.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping a bar reports its ply index', (tester) async {
    int? selected;
    final curve = [10, -20, 30, null, -5];

    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 300,
          height: 80,
          child: ScoreCurve(
            curve: curve,
            onSelectPly: (ply) => selected = ply,
          ),
        ),
      ),
    ));

    final rect = tester.getRect(find.byType(ScoreCurve));
    final barWidth = rect.width / curve.length;
    // Tap into the 4th bar (index 3, the null entry).
    await tester.tapAt(rect.topLeft + Offset(barWidth * 3.5, rect.height / 2));
    await tester.pump();

    expect(selected, 3);
  });

  testWidgets('renders without a tap handler', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SizedBox(
        width: 300,
        height: 80,
        child: ScoreCurve(curve: [1, 2, 3]),
      ),
    ));

    expect(find.byType(ScoreCurve), findsOneWidget);
  });
}
