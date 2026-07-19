import 'package:chess_practice/game/difficulty.dart';
import 'package:chess_practice/xiangqi/piece.dart';
import 'package:chess_practice/xiangqi/xq_engine_value.dart';
import 'package:chess_practice/xiangqi/xq_game_record.dart';
import 'package:chess_practice/xiangqi/xq_game_review.dart';
import 'package:chess_practice/xiangqi/xq_move_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyXqLoss', () {
    test('buckets are ordered and cover the whole range', () {
      expect(classifyXqLoss(0), XqMoveQuality.best);
      expect(classifyXqLoss(10), XqMoveQuality.best);
      expect(classifyXqLoss(11), XqMoveQuality.good);
      expect(classifyXqLoss(50), XqMoveQuality.good);
      expect(classifyXqLoss(51), XqMoveQuality.inaccuracy);
      expect(classifyXqLoss(100), XqMoveQuality.inaccuracy);
      expect(classifyXqLoss(101), XqMoveQuality.mistake);
      expect(classifyXqLoss(300), XqMoveQuality.mistake);
      expect(classifyXqLoss(301), XqMoveQuality.blunder);
    });
  });

  group('xqMoveLoss', () {
    test('a perfectly played move has zero loss', () {
      const before = XqPositionEval(score: 30, pv: []);
      const after = XqPositionEval(score: -30, pv: []);
      expect(xqMoveLoss(before, after), 0);
    });

    test('a blunder that hands the opponent a big score has large loss', () {
      const before = XqPositionEval(score: 20, pv: []);
      const after = XqPositionEval(score: 400, pv: []);
      expect(xqMoveLoss(before, after), 420);
    });

    test('allowing a forced mate registers as a huge loss', () {
      const before = XqPositionEval(score: 30, pv: []);
      const after = XqPositionEval(score: xqMateValue - 1, pv: []);
      expect(classifyXqLoss(xqMoveLoss(before, after)), XqMoveQuality.blunder);
    });
  });

  group('XqGameReview.redPovCurve', () {
    test('flips Black-to-move evals to a common Red POV', () {
      final record = XqGameRecord(
        difficulty: Difficulty.normal,
        startedAt: DateTime(2026, 7, 19),
        moves: [
          XqMoveRecord(
            side: Side.red,
            fromX: 7,
            fromY: 2,
            toX: 4,
            toY: 2,
            timestamp: DateTime(2026, 7, 19),
          ),
        ],
        winner: null,
        humanSide: Side.red,
      );
      final review = XqGameReview(
        record: record,
        evals: const [
          XqPositionEval(score: 20, pv: []), // pos 0: Red to move
          XqPositionEval(score: 15, pv: []), // pos 1: Black to move
        ],
        moveReviews: const [],
      );
      expect(review.redPovCurve, [20, -15]);
    });
  });
}
