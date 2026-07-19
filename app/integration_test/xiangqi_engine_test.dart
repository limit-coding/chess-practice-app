// Step 4.2 acceptance: select-then-move on the Xiangqi board drives the
// real Pikafish engine through FFI and gets a legal reply, with no error
// status appearing.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:chess_practice/main.dart';
import 'package:chess_practice/widgets/xiangqi_board_view.dart';
import 'package:chess_practice/xiangqi/fen.dart';

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxTries = 60,
}) async {
  for (var i = 0; i < maxTries && !condition(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('selecting a piece and moving it gets an engine reply through FFI',
      (tester) async {
    await tester.pumpWidget(const ChessPracticeApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('象棋'));
    await tester.pumpAndSettle();

    // Easy difficulty keeps the engine's think time short for the test.
    await tester.tap(find.text('简单'));
    await tester.pump();

    await tester.tap(find.text('开始对局'));
    await _waitUntil(tester, () => find.text('轮到你走子（红方）').evaluate().isNotEmpty);
    expect(find.text('轮到你走子（红方）'), findsOneWidget);

    final rect = tester.getRect(find.byType(XiangqiBoardView));
    final cellW = rect.width / xqFiles;
    final cellH = rect.height / xqRanks;
    Offset boardPoint(int x, int y) {
      final screenRow = xqRanks - 1 - y;
      return rect.topLeft + Offset(cellW * (x + 0.5), cellH * (screenRow + 0.5));
    }

    // Red's opening cannon move h2e2: select (7,2), then move to (4,2).
    await tester.tapAt(boardPoint(7, 2));
    await tester.pump();
    await tester.tapAt(boardPoint(4, 2));
    await tester.pump();

    bool settled() =>
        find.textContaining('引擎错误').evaluate().isNotEmpty ||
        find.textContaining('未响应').evaluate().isNotEmpty ||
        find.text('轮到你走子（红方）').evaluate().isNotEmpty ||
        find.text('你赢了！').evaluate().isNotEmpty ||
        find.text('引擎赢了。').evaluate().isNotEmpty;
    await _waitUntil(tester, settled, maxTries: 80);

    expect(find.textContaining('引擎错误'), findsNothing, reason: '引擎应答不应报错');
    expect(find.textContaining('未响应'), findsNothing, reason: '引擎不应超时未响应');
    expect(find.text('轮到你走子（红方）'), findsOneWidget, reason: '引擎应对后应该轮到玩家走子');
  });
}
