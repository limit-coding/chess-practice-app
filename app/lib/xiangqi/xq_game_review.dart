// Step 4.3: Xiangqi analogue of game/game_review.dart. Re-evaluates every
// position of a finished game through Pikafish (independent of whatever
// difficulty was actually played) to build a score curve, then classifies
// each move by how much it cost the mover — same negamax-loss idea as the
// Gomoku reviewer, just fed by UCI `info score cp/mate` instead of
// Gomocup's `MESSAGE Eval`.
import '../engine/pikafish_ffi.dart';
import 'xq_engine_value.dart';
import 'xq_game_record.dart';
import 'xq_move.dart';
import 'xq_move_record.dart';

/// Search budget for post-game analysis, independent of the difficulty the
/// game was actually played at. First-pass estimate — tune once real games
/// suggest a better time/quality tradeoff.
const int xqReviewThinkMs = 800;

class XqPositionEval {
  const XqPositionEval({required this.score, required this.pv});

  /// Centipawns from the point of view of whoever is to move at this
  /// position (mate scores folded onto the same line, see xqMateValue).
  final int score;
  final List<XqMove> pv;
}

enum XqMoveQuality {
  best('最佳'),
  good('好棋'),
  inaccuracy('不精确'),
  mistake('错误'),
  blunder('漏着');

  const XqMoveQuality(this.label);
  final String label;
}

/// First-pass thresholds in centipawns — not calibrated against a large
/// sample of real games. Adjust freely once real play data suggests better
/// cutoffs (same caveat as Gomoku's `classifyLoss`).
XqMoveQuality classifyXqLoss(int loss) {
  if (loss <= 10) return XqMoveQuality.best;
  if (loss <= 50) return XqMoveQuality.good;
  if (loss <= 100) return XqMoveQuality.inaccuracy;
  if (loss <= 300) return XqMoveQuality.mistake;
  return XqMoveQuality.blunder;
}

/// Same negamax-loss formula as Gomoku's `moveLoss`: both evals are in
/// their own mover-to-move's point of view, so a perfectly played move
/// keeps `before.score + after.score` close to zero.
int xqMoveLoss(XqPositionEval before, XqPositionEval after) {
  final raw = before.score + after.score;
  return raw < 0 ? 0 : raw;
}

class XqMoveReview {
  const XqMoveReview({
    required this.ply,
    required this.move,
    required this.loss,
    required this.quality,
  });

  final int ply;
  final XqMoveRecord move;
  final int loss;
  final XqMoveQuality quality;
}

class XqGameReview {
  const XqGameReview({
    required this.record,
    required this.evals,
    required this.moveReviews,
  });

  final XqGameRecord record;

  /// Length `record.moves.length + 1`. `evals[i]` is the position just
  /// before `record.moves[i]` is played; `null` if that position's engine
  /// query failed.
  final List<XqPositionEval?> evals;

  final List<XqMoveReview> moveReviews;

  /// Score curve in a single consistent point of view (Red's — Red always
  /// moves first and is the default human side): positive favors Red,
  /// negative favors Black.
  List<int?> get redPovCurve => [
        for (var i = 0; i < evals.length; i++)
          evals[i] == null ? null : (i.isEven ? evals[i]!.score : -evals[i]!.score),
      ];
}

/// Runs the per-position engine evaluation for a finished Xiangqi game.
/// Assumes `PikafishEngine.instance` has already been started (with the
/// NNUE file wired up) by the live game that produced [XqGameRecord] —
/// review only calls `ucinewgame` to clear hash between positions.
class XqGameReviewer {
  const XqGameReviewer();

  Future<XqGameReview> review(
    XqGameRecord record, {
    void Function(int done, int total)? onProgress,
  }) async {
    final n = record.moves.length;
    final total = n + 1;
    final evals = List<XqPositionEval?>.filled(total, null);

    PikafishEngine.instance.newGame();

    for (var i = 0; i <= n; i++) {
      evals[i] = await _evalPosition(record, i);
      onProgress?.call(i + 1, total);
    }

    final moveReviews = <XqMoveReview>[];
    for (var i = 0; i < n; i++) {
      final before = evals[i];
      final after = evals[i + 1];
      if (before == null || after == null) continue;
      final loss = xqMoveLoss(before, after);
      moveReviews.add(XqMoveReview(
        ply: i,
        move: record.moves[i],
        loss: loss,
        quality: classifyXqLoss(loss),
      ));
    }

    return XqGameReview(record: record, evals: evals, moveReviews: moveReviews);
  }

  /// Position `i` is the board just before move `i` would be played
  /// (`i == record.moves.length` is the final, game-over position — no
  /// legal moves exist there, so instead of asking the engine to search
  /// it, its value is definitional: whoever would move next already lost).
  Future<XqPositionEval?> _evalPosition(XqGameRecord record, int i) async {
    final n = record.moves.length;

    if (i == n && record.winner != null) {
      return const XqPositionEval(score: -xqMateValue, pv: []);
    }

    final prefix = record.moves
        .sublist(0, i)
        .map((m) => XqMove(m.fromX, m.fromY, m.toX, m.toY).uci)
        .toList();
    PikafishEngine.instance.setPosition(moves: prefix);
    final (_, _, log) = await PikafishEngine.instance.goMoveTime(xqReviewThinkMs);

    final info = lastSearchInfo(log);
    if (info == null) return null;
    return XqPositionEval(score: info.score, pv: info.pv);
  }
}
