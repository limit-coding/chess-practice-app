// Step 4.3 acceptance: re-evaluating a finished Xiangqi game's positions
// through the real (FFI-backed) engine produces a complete score curve, and
// playing a reviewed hint move can resume live play with a valid engine
// reply — the Xiangqi analogue of integration_test/review_test.dart.
import 'package:chess_practice/engine/pikafish_assets.dart';
import 'package:chess_practice/engine/pikafish_ffi.dart';
import 'package:chess_practice/game/difficulty.dart';
import 'package:chess_practice/xiangqi/piece.dart';
import 'package:chess_practice/xiangqi/xiangqi_game.dart';
import 'package:chess_practice/xiangqi/xq_game_record.dart';
import 'package:chess_practice/xiangqi/xq_game_review.dart';
import 'package:chess_practice/xiangqi/xq_move.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'XqGameReviewer produces a complete score curve via the real engine',
    (tester) async {
      final evalFile = await const PikafishAssets().ensureNetworkFile();
      await PikafishEngine.instance.start(evalFile: evalFile);

      final moves = [
        const XqMove(7, 2, 4, 2), // red cannon h2e2
        const XqMove(1, 7, 4, 7), // black cannon b7e7
        const XqMove(0, 3, 0, 4), // red soldier a3a4
        const XqMove(6, 6, 6, 5), // black soldier g6g5
      ];
      final game = XiangqiGame();
      for (final m in moves) {
        game.play(m);
      }
      expect(game.moves.length, moves.length, reason: '测试局面里的每一步都应该是合法走法');

      final record = XqGameRecord.fromGame(
        game,
        difficulty: Difficulty.easy,
        startedAt: DateTime.now(),
        humanSide: Side.red,
      );

      final progressCalls = <(int, int)>[];
      final review = await const XqGameReviewer().review(
        record,
        onProgress: (done, total) => progressCalls.add((done, total)),
      );

      expect(review.evals.length, moves.length + 1);
      expect(review.evals.every((e) => e != null), isTrue,
          reason: '每个局面都应该拿到引擎评分，不应该有缺失');
      expect(review.moveReviews.length, moves.length);
      expect(progressCalls, isNotEmpty);
      expect(progressCalls.last, (moves.length + 1, moves.length + 1));
      expect(review.evals.any((e) => e!.pv.isNotEmpty), isTrue);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'playing a reviewed hint move and resuming gets a valid engine reply',
    (tester) async {
      final evalFile = await const PikafishAssets().ensureNetworkFile();
      await PikafishEngine.instance.start(evalFile: evalFile);

      final moves = [
        const XqMove(7, 2, 4, 2),
        const XqMove(1, 7, 4, 7),
      ];
      final game = XiangqiGame();
      for (final m in moves) {
        game.play(m);
      }
      expect(game.moves.length, moves.length, reason: '测试局面里的每一步都应该是合法走法');
      final record = XqGameRecord.fromGame(
        game,
        difficulty: Difficulty.easy,
        startedAt: DateTime.now(),
        humanSide: Side.red,
      );

      final review = await const XqGameReviewer().review(record);

      // Ply 0 is Red's (the human's) first move.
      const ply = 0;
      final hintEval = review.evals[ply]!;
      expect(hintEval.pv, isNotEmpty);
      final hint = hintEval.pv.first;

      final resumed = XiangqiGame.replay(record.moves.sublist(0, ply));
      expect(resumed.turn, Side.red);

      resumed.play(hint);
      final uciMoves =
          resumed.moves.map((m) => XqMove(m.fromX, m.fromY, m.toX, m.toY).uci).toList();
      PikafishEngine.instance.setPosition(moves: uciMoves);
      final (bestMoveUci, _, log) =
          await PikafishEngine.instance.goMoveTime(record.difficulty.thinkMs);

      expect(bestMoveUci, isNotNull);
      final engineMove = XqMove.fromUci(bestMoveUci!);
      expect(engineMove, isNotNull,
          reason: '恢复对弈后引擎应该返回一个合法走法，而不是错误或超时: $log');

      final applied = resumed.play(engineMove!);
      expect(applied, isNotNull, reason: '引擎的应对应该是棋盘上一个合法走法');
      expect(resumed.moves.length, ply + 2);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
