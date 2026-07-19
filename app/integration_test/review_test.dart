// Step 2.1 acceptance: re-evaluating a finished game's positions through
// the real (FFI-backed) engine must produce one eval per position — a
// complete score curve — with no gaps and no errors.
import 'package:chess_practice/engine/rapfi_ffi.dart';
import 'package:chess_practice/game/difficulty.dart';
import 'package:chess_practice/game/game_record.dart';
import 'package:chess_practice/game/game_review.dart';
import 'package:chess_practice/game/game_state.dart';
import 'package:chess_practice/game/move_record.dart';
import 'package:chess_practice/game/stone.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'GameReviewer produces a complete score curve via the real engine',
    (tester) async {
      final rawMoves = [
        (Stone.black, 7, 7),
        (Stone.white, 6, 6),
        (Stone.black, 7, 8),
        (Stone.white, 6, 7),
        (Stone.black, 8, 7),
        (Stone.white, 5, 5),
      ];
      final moves = rawMoves
          .map((m) => MoveRecord(stone: m.$1, x: m.$2, y: m.$3, timestamp: DateTime.now()))
          .toList();

      final record = GameRecord(
        boardSize: 15,
        difficulty: Difficulty.easy,
        startedAt: DateTime.now(),
        moves: moves,
        winner: null,
      );

      final progressCalls = <(int, int)>[];
      final review = await const GameReviewer().review(
        record,
        onProgress: (done, total) => progressCalls.add((done, total)),
      );

      expect(review.evals.length, moves.length + 1);
      expect(review.evals.every((e) => e != null), isTrue,
          reason: '每个局面都应该拿到引擎评分，不应该有缺失');
      expect(review.moveReviews.length, moves.length,
          reason: '每一步都应该有对应的分类结果');
      expect(progressCalls, isNotEmpty);
      expect(progressCalls.last, (moves.length + 1, moves.length + 1));

      // Sanity check the PV that step 2.5's hint feature depends on: at
      // least some positions should carry a non-empty recommended line.
      expect(review.evals.any((e) => e!.bestLine.isNotEmpty), isTrue);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'playing a reviewed hint move and resuming gets a valid engine reply',
    (tester) async {
      final rawMoves = [
        (Stone.black, 7, 7),
        (Stone.white, 6, 6),
        (Stone.black, 7, 8),
        (Stone.white, 6, 7),
      ];
      final moves = rawMoves
          .map((m) => MoveRecord(stone: m.$1, x: m.$2, y: m.$3, timestamp: DateTime.now()))
          .toList();
      final record = GameRecord(
        boardSize: 15,
        difficulty: Difficulty.easy,
        startedAt: DateTime.now(),
        moves: moves,
        winner: null,
      );

      final review = await const GameReviewer().review(record);

      // Ply 2 is Black's second move; step 2.5 only offers hints for the
      // human's own moves.
      const ply = 2;
      final hintEval = review.evals[ply]!;
      expect(hintEval.bestLine, isNotEmpty);
      final hint = hintEval.bestLine.first;

      // 2.4: rewind to the position right before that move, purely locally.
      final game = GomokuGame.replay(record.boardSize, record.moves.sublist(0, ply));
      expect(game.moves.length, ply);
      expect(game.turn, Stone.black);

      // 2.5: play the hint, then resume live play — the engine must reply.
      game.play(hint.$1, hint.$2);
      RapfiEngine.instance.setSearchBudget(
        thinkMs: record.difficulty.thinkMs,
        maxDepth: record.difficulty.maxDepth,
      );
      final (engineMove, log) = await RapfiEngine.instance.setBoard(game.moves);

      expect(engineMove, isNotNull);
      expect(RegExp(r'^\d+,\d+$').hasMatch(engineMove!), isTrue,
          reason: '恢复对弈后引擎应该返回一个合法落子，而不是错误或超时: $log');

      final parts = engineMove.split(',');
      final record2 = game.play(int.parse(parts[0]), int.parse(parts[1]));
      expect(record2, isNotNull, reason: '引擎的应对应该是棋盘上一个合法的空位');
      expect(game.moves.length, ply + 2);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
