// Step 2.1/2.2: re-evaluates every position of a finished game with the
// engine (independent of whatever difficulty was actually played) to build
// a score curve, then classifies each move by how much it cost the mover.
import '../engine/rapfi_ffi.dart';
import 'engine_value.dart';
import 'game_record.dart';
import 'move_record.dart';

/// Search budget used for post-game analysis — independent of the
/// difficulty the game was actually played at, so review quality doesn't
/// depend on it. Deliberately stronger than [Difficulty.normal] but capped
/// well below [Difficulty.hard] to keep a full game's review to a
/// reasonable wall-clock time (one engine call per ply).
const int reviewThinkMs = 700;
const int reviewMaxDepth = 18;

/// One position's engine evaluation, from the point of view of whoever is
/// to move there. Mate scores are folded onto the same numeric line as
/// [valueMate] minus the mate distance (see engine_value.dart).
class PositionEval {
  const PositionEval({required this.score, required this.bestLine});

  final int score;
  final List<(int, int)> bestLine;

  bool get isMateForMover => score >= valueMate - 500;
  bool get isMateAgainstMover => score <= -(valueMate - 500);
}

enum MoveQuality {
  best('最佳'),
  good('好棋'),
  inaccuracy('不精确'),
  mistake('错误'),
  blunder('漏着');

  const MoveQuality(this.label);
  final String label;
}

/// Classifies a move by how many points it cost the mover, relative to the
/// engine's assessment of the position just before the move.
///
/// These thresholds are in Rapfi's own eval units (not centipawns — the
/// engine's scale tops out at [valueMate] = 30000) and are a first-pass
/// estimate, not calibrated against a large sample of real games. Adjust
/// freely once real play data suggests better cutoffs.
MoveQuality classifyLoss(int loss) {
  if (loss <= 20) return MoveQuality.best;
  if (loss <= 100) return MoveQuality.good;
  if (loss <= 400) return MoveQuality.inaccuracy;
  if (loss <= 1200) return MoveQuality.mistake;
  return MoveQuality.blunder;
}

/// How much worse [before] -> [after] was for whoever made the move,
/// compared to the engine's assessment of the position beforehand.
///
/// Both evals are in their own mover-to-move's point of view (standard
/// negamax convention), so a perfectly-played move keeps
/// `before.score + after.score` close to zero; a mistake pushes it
/// positive. Clamped to 0 since search noise can occasionally make it
/// slightly negative for an objectively fine move.
int moveLoss(PositionEval before, PositionEval after) {
  final raw = before.score + after.score;
  return raw < 0 ? 0 : raw;
}

class MoveReview {
  const MoveReview({
    required this.ply,
    required this.move,
    required this.loss,
    required this.quality,
  });

  final int ply; // 0-indexed position in GameRecord.moves
  final MoveRecord move;
  final int loss;
  final MoveQuality quality;
}

class GameReview {
  const GameReview({
    required this.record,
    required this.evals,
    required this.moveReviews,
  });

  final GameRecord record;

  /// Length `record.moves.length + 1`. `evals[i]` is the position just
  /// before `record.moves[i]` is played (`evals[0]` is the empty board);
  /// entries are `null` if that position's engine query failed.
  final List<PositionEval?> evals;

  /// One entry per move whose surrounding evals were both available.
  final List<MoveReview> moveReviews;

  /// The score curve in a single consistent point of view (Black's — Black
  /// always moves first and is always the human), for charting: positive
  /// favors the human, negative favors the engine.
  List<int?> get blackPovCurve => [
        for (var i = 0; i < evals.length; i++)
          evals[i] == null ? null : (i.isEven ? evals[i]!.score : -evals[i]!.score),
      ];
}

/// Runs the per-position engine evaluation for a finished game.
class GameReviewer {
  const GameReviewer();

  /// [onProgress] reports `(positionsDone, totalPositions)` as the review
  /// proceeds — a full game means one engine call per position, so this can
  /// take a while for long games.
  Future<GameReview> review(
    GameRecord record, {
    void Function(int done, int total)? onProgress,
  }) async {
    final n = record.moves.length;
    final total = n + 1;
    final evals = List<PositionEval?>.filled(total, null);

    await RapfiEngine.instance.startGame(
      boardSize: record.boardSize,
      thinkMs: reviewThinkMs,
      maxDepth: reviewMaxDepth,
    );

    for (var i = 0; i <= n; i++) {
      evals[i] = await _evalPosition(record, i);
      onProgress?.call(i + 1, total);
    }

    final moveReviews = <MoveReview>[];
    for (var i = 0; i < n; i++) {
      final before = evals[i];
      final after = evals[i + 1];
      if (before == null || after == null) continue;
      final loss = moveLoss(before, after);
      moveReviews.add(MoveReview(
        ply: i,
        move: record.moves[i],
        loss: loss,
        quality: classifyLoss(loss),
      ));
    }

    return GameReview(record: record, evals: evals, moveReviews: moveReviews);
  }

  /// Position `i` is the board just before move `i` would be played
  /// (`i == record.moves.length` is the final, post-game-over position).
  Future<PositionEval?> _evalPosition(GameRecord record, int i) async {
    final n = record.moves.length;

    // The empty board is a fixed opening-book shortcut in Rapfi
    // (search/opening.cpp: `ply() == 0` always just returns the center
    // point for FREEOPEN) — it never runs a real search, so there's no
    // Eval/Bestline message to parse. Treat it as the conventional
    // dead-even starting position instead of querying the engine.
    if (i == 0) {
      return const PositionEval(score: 0, bestLine: []);
    }

    // The final position of a decisive game already has a completed
    // five-in-a-row on the board — not a position Rapfi is meant to search
    // from. Its value is definitional: whoever would move next already
    // lost.
    if (i == n && record.winner != null) {
      return const PositionEval(score: -valueMate, bestLine: []);
    }
    // A full board with no winner is a draw — also nothing to search.
    if (i == n && record.winner == null && n == record.boardSize * record.boardSize) {
      return const PositionEval(score: 0, bestLine: []);
    }

    final prefix = record.moves.sublist(0, i);
    final (_, log) = await RapfiEngine.instance.setBoard(prefix);

    int? score;
    List<(int, int)> bestLine = const [];
    for (final line in log) {
      final v = parseEvalFromMessageLine(line);
      if (v != null) score = v;
      if (line.startsWith('MESSAGE Bestline')) {
        bestLine = parseBestlineFromMessageLine(line);
      }
    }

    if (score == null) return null;
    return PositionEval(score: score, bestLine: bestLine);
  }
}
