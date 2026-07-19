// Step 1.3 acceptance: a full human-vs-engine turn (player taps a cell, the
// engine answers through FFI, both stones land on the board) must complete
// without any error status appearing.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:chess_practice/main.dart';
import 'package:chess_practice/widgets/board_view.dart';

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

  testWidgets('player move gets an engine reply through FFI', (tester) async {
    await tester.pumpWidget(const ChessPracticeApp());
    await tester.pumpAndSettle();

    // Easy difficulty keeps the engine's think time short for the test.
    await tester.tap(find.text('简单'));
    await tester.pump();

    await tester.tap(find.text('开始对局'));
    await _waitUntil(tester, () => find.text('轮到你落子（黑棋）').evaluate().isNotEmpty);
    expect(find.text('轮到你落子（黑棋）'), findsOneWidget);

    // Tap near the board's center intersection.
    final boardRect = tester.getRect(find.byType(BoardView));
    final cell = boardRect.width / 15;
    final tapPoint = boardRect.topLeft + Offset(cell * 7.5, cell * 7.5);
    await tester.tapAt(tapPoint);
    await tester.pump();

    bool settled() =>
        find.textContaining('引擎错误').evaluate().isNotEmpty ||
        find.textContaining('未响应').evaluate().isNotEmpty ||
        find.text('轮到你落子（黑棋）').evaluate().isNotEmpty ||
        find.text('你赢了！').evaluate().isNotEmpty ||
        find.text('引擎赢了。').evaluate().isNotEmpty ||
        find.text('平局。').evaluate().isNotEmpty;
    await _waitUntil(tester, settled);

    expect(find.textContaining('引擎错误'), findsNothing,
        reason: '引擎应答不应报错');
    expect(find.textContaining('未响应'), findsNothing, reason: '引擎不应超时未响应');
  });

  testWidgets('letting the engine open the game plays its first move via FFI',
      (tester) async {
    await tester.pumpWidget(const ChessPracticeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('简单'));
    await tester.pump();
    await tester.tap(find.text('AI先手'));
    await tester.pump();

    await tester.tap(find.text('开始对局'));
    await _waitUntil(
      tester,
      () =>
          find.text('轮到你落子（白棋）').evaluate().isNotEmpty ||
          find.textContaining('引擎错误').evaluate().isNotEmpty ||
          find.textContaining('未响应').evaluate().isNotEmpty,
    );

    expect(find.textContaining('引擎错误'), findsNothing, reason: '引擎开局不应报错');
    expect(find.textContaining('未响应'), findsNothing, reason: '引擎开局不应超时');
    expect(find.text('轮到你落子（白棋）'), findsOneWidget,
        reason: 'AI 先手落子后应该轮到玩家（执白）落子');
  });
}
