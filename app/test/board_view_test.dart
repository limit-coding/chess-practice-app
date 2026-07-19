import 'package:chess_practice/game/stone.dart';
import 'package:chess_practice/widgets/board_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<List<Stone?>> _emptyBoard(int size) =>
    List.generate(size, (_) => List<Stone?>.filled(size, null));

void main() {
  const board = BoardView(boardSize: 15, board: []);

  group('BoardView.localToCell', () {
    test('maps each cell center back to itself', () {
      const side = 300.0;
      const cell = side / 15;
      for (var y = 0; y < 15; y++) {
        for (var x = 0; x < 15; x++) {
          final local = Offset((x + 0.5) * cell, (y + 0.5) * cell);
          expect(board.localToCell(local, side), (x, y));
        }
      }
    });

    test('clamps taps outside the board to the nearest edge cell', () {
      const side = 300.0;
      expect(board.localToCell(const Offset(-10, -10), side), (0, 0));
      expect(board.localToCell(const Offset(10000, 10000), side), (14, 14));
    });
  });

  testWidgets('tapping the board reports the tapped cell', (tester) async {
    (int, int)? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 300,
          height: 300,
          child: BoardView(
            boardSize: 15,
            board: _emptyBoard(15),
            onTapCell: (x, y) => tapped = (x, y),
          ),
        ),
      ),
    ));

    // SizedBox only honors 300x300 once its parent isn't handing it tight
    // (fullscreen) constraints — Center makes that true. Read the actual
    // rendered rect rather than assuming it, so the test doesn't depend on
    // the test surface's default size.
    final rect = tester.getRect(find.byType(BoardView));
    final cell = rect.width / 15;
    // Tap the intersection for cell (3, 10).
    await tester.tapAt(rect.topLeft + Offset(cell * 3.5, cell * 10.5));
    await tester.pump();

    expect(tapped, (3, 10));
  });
}
