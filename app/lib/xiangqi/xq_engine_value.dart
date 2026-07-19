// Parses Pikafish's UCI "info ... score cp/mate ... pv ..." lines — the
// analogue of game/engine_value.dart for the Gomoku/Gomocup protocol.
import 'xq_move.dart';

/// Matches the same role as `valueMate` in engine_value.dart: large enough
/// that no real (non-mate) evaluation could reach it, so mate scores stay
/// directly comparable on the same numeric line as normal centipawn scores.
const int xqMateValue = 30000;

class UciSearchInfo {
  const UciSearchInfo({required this.score, required this.pv});

  /// Centipawns from the side-to-move's own point of view (standard UCI
  /// convention) — mate scores are folded onto this same line as
  /// `xqMateValue - pliesToMate`.
  final int score;
  final List<XqMove> pv;
}

/// Parses one `info depth ... score cp N ... pv <moves>` (or `score mate
/// N`) line. Returns `null` if the line isn't an info line with a score
/// (e.g. it has no "score" field, or isn't an "info" line at all).
UciSearchInfo? parseUciInfoLine(String line) {
  if (!line.startsWith('info')) return null;
  final tokens = line.trim().split(RegExp(r'\s+'));

  int? score;
  final pv = <XqMove>[];

  for (var i = 0; i < tokens.length; i++) {
    if (tokens[i] == 'score' && i + 2 < tokens.length) {
      final kind = tokens[i + 1];
      final value = int.tryParse(tokens[i + 2]);
      if (value == null) continue;
      if (kind == 'cp') {
        score = value;
      } else if (kind == 'mate') {
        score = value >= 0 ? xqMateValue - value : -xqMateValue - value;
      }
    } else if (tokens[i] == 'pv') {
      for (var j = i + 1; j < tokens.length; j++) {
        final move = XqMove.fromUci(tokens[j]);
        if (move != null) pv.add(move);
      }
      break; // "pv" is always the last field in a UCI info line.
    }
  }

  if (score == null) return null;
  return UciSearchInfo(score: score, pv: pv);
}

/// Scans engine output (as collected by `PikafishEngine.goMoveTime`'s log)
/// for the last info line carrying a score — the final/deepest search
/// iteration's assessment.
UciSearchInfo? lastSearchInfo(List<String> log) {
  UciSearchInfo? last;
  for (final line in log) {
    final info = parseUciInfoLine(line);
    if (info != null) last = info;
  }
  return last;
}
