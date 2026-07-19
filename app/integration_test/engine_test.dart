// Step 0.6 acceptance: on a real device/simulator, tapping the button must
// produce an engine move rendered as "引擎开局: x,y".
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';

import 'package:chess_practice/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('engine answers with a move through FFI', (tester) async {
    await tester.pumpWidget(const SpikeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton));

    // Engine thinks up to 2s; poll the tree until the move line appears.
    final moveLine = RegExp(r'引擎开局: \d+,\d+');
    var found = false;
    for (var i = 0; i < 40 && !found; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      found = find
          .byWidgetPredicate((w) => w is Text && moveLine.hasMatch(w.data ?? ''))
          .evaluate()
          .isNotEmpty;
    }
    expect(found, isTrue, reason: '未在 20 秒内看到引擎落子输出');
  });
}
