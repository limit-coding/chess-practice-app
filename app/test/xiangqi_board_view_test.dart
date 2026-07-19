import 'package:chess_practice/widgets/xiangqi_board_view.dart';
import 'package:chess_practice/xiangqi/fen.dart';
import 'package:chess_practice/xiangqi/piece.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<List<XqPiece?>> emptySquares() =>
    List.generate(xqRanks, (_) => List<XqPiece?>.filled(xqFiles, null));

void main() {
  const board = XiangqiBoardView(squares: []);

  group('XiangqiBoardView.localToCell', () {
    test('maps each cell center back to itself, flipping y so red is at the bottom', () {
      const cell = 30.0;
      const width = cell * xqFiles;
      const height = cell * xqRanks;
      for (var y = 0; y < xqRanks; y++) {
        for (var x = 0; x < xqFiles; x++) {
          final screenRow = xqRanks - 1 - y;
          final local = Offset((x + 0.5) * cell, (screenRow + 0.5) * cell);
          expect(board.localToCell(local, width, height), (x, y));
        }
      }
    });

    test('red back rank (y=0) is at the bottom of the screen', () {
      const cell = 30.0;
      const width = cell * xqFiles;
      const height = cell * xqRanks;
      // Bottom-most row on screen.
      final local = const Offset(4.5 * cell, height - cell / 2);
      expect(board.localToCell(local, width, height), (4, 0));
    });
  });

  testWidgets('tapping a cell reports its board coordinate', (tester) async {
    (int, int)? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 360,
          height: 400,
          child: XiangqiBoardView(
            squares: emptySquares(),
            onTapCell: (x, y) => tapped = (x, y),
          ),
        ),
      ),
    ));

    final rect = tester.getRect(find.byType(XiangqiBoardView));
    final cellW = rect.width / xqFiles;
    final cellH = rect.height / xqRanks;
    // Tap the intersection for board (2, 8) — near the top (black's side).
    final screenRow = xqRanks - 1 - 8;
    await tester.tapAt(rect.topLeft + Offset(cellW * 2.5, cellH * (screenRow + 0.5)));
    await tester.pump();

    expect(tapped, (2, 8));
  });
}
