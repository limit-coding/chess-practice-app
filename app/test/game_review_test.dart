import 'package:chess_practice/game/difficulty.dart';
import 'package:chess_practice/game/engine_value.dart';
import 'package:chess_practice/game/game_record.dart';
import 'package:chess_practice/game/game_review.dart';
import 'package:chess_practice/game/move_record.dart';
import 'package:chess_practice/game/stone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyLoss', () {
    test('buckets are ordered and cover the whole range', () {
      expect(classifyLoss(0), MoveQuality.best);
      expect(classifyLoss(20), MoveQuality.best);
      expect(classifyLoss(21), MoveQuality.good);
      expect(classifyLoss(100), MoveQuality.good);
      expect(classifyLoss(101), MoveQuality.inaccuracy);
      expect(classifyLoss(400), MoveQuality.inaccuracy);
      expect(classifyLoss(401), MoveQuality.mistake);
      expect(classifyLoss(1200), MoveQuality.mistake);
      expect(classifyLoss(1201), MoveQuality.blunder);
      expect(classifyLoss(29999), MoveQuality.blunder);
    });
  });

  group('moveLoss', () {
    test('a perfectly played move (evals sum to ~0) has zero loss', () {
      const before = PositionEval(score: 120, bestLine: []);
      const after = PositionEval(score: -120, bestLine: []); // opponent's POV
      expect(moveLoss(before, after), 0);
    });

    test('a blunder that hands the opponent a big score has large loss', () {
      const before = PositionEval(score: 50, bestLine: []);
      const after = PositionEval(score: 900, bestLine: []); // now great for opponent
      expect(moveLoss(before, after), 950);
    });

    test('small negative raw loss (search noise) clamps to zero', () {
      const before = PositionEval(score: 10, bestLine: []);
      const after = PositionEval(score: -30, bestLine: []);
      expect(moveLoss(before, after), 0);
    });

    test('a move that allows a forced mate registers as a huge loss', () {
      const before = PositionEval(score: 80, bestLine: []);
      const after = PositionEval(score: valueMate - 1, bestLine: []); // opponent mates in 1
      expect(moveLoss(before, after), greaterThan(1200));
      expect(classifyLoss(moveLoss(before, after)), MoveQuality.blunder);
    });
  });

  group('GameReview', () {
    GameRecord recordWith(List<MoveRecord> moves, {Stone? winner}) => GameRecord(
          boardSize: 15,
          difficulty: Difficulty.normal,
          startedAt: DateTime(2026, 7, 19),
          moves: moves,
          winner: winner,
        );

    MoveRecord move(Stone stone, int x, int y) =>
        MoveRecord(stone: stone, x: x, y: y, timestamp: DateTime(2026, 7, 19));

    test('blackPovCurve flips White-to-move evals to a common Black POV', () {
      final record = recordWith([
        move(Stone.black, 7, 7),
        move(Stone.white, 6, 6),
      ]);
      final review = GameReview(
        record: record,
        evals: const [
          PositionEval(score: 10, bestLine: []), // pos 0: Black to move
          PositionEval(score: 30, bestLine: []), // pos 1: White to move
          PositionEval(score: -5, bestLine: []), // pos 2: Black to move
        ],
        moveReviews: const [],
      );
      expect(review.blackPovCurve, [10, -30, -5]);
    });

    test('blackPovCurve preserves nulls for missing evaluations', () {
      final record = recordWith([move(Stone.black, 7, 7)]);
      final review = GameReview(
        record: record,
        evals: const [PositionEval(score: 0, bestLine: []), null],
        moveReviews: const [],
      );
      expect(review.blackPovCurve, [0, null]);
    });
  });
}
