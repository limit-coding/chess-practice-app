import 'package:chess_practice/xiangqi/xq_engine_value.dart';
import 'package:chess_practice/xiangqi/xq_move.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseUciInfoLine', () {
    test('parses a plain centipawn score and PV', () {
      const line = 'info depth 12 seldepth 16 multipv 1 score cp 37 nodes 16752 '
          'nps 797714 hashfull 6 tbhits 0 time 21 pv h2e2 h9g7 h0g2';
      final info = parseUciInfoLine(line);
      expect(info, isNotNull);
      expect(info!.score, 37);
      expect(info.pv, [
        const XqMove(7, 2, 4, 2),
        const XqMove(7, 9, 6, 7),
        const XqMove(7, 0, 6, 2),
      ]);
    });

    test('parses a mate score onto the same numeric line as xqMateValue', () {
      const line = 'info depth 8 score mate 3 nodes 100 pv c3c4';
      final info = parseUciInfoLine(line);
      expect(info!.score, xqMateValue - 3);
    });

    test('a negative mate score (being mated) is negative', () {
      const line = 'info depth 8 score mate -2 nodes 100 pv c3c4';
      final info = parseUciInfoLine(line);
      expect(info!.score, -xqMateValue + 2);
    });

    test('returns null for lines with no score field', () {
      expect(parseUciInfoLine('info string some diagnostic message'), isNull);
    });

    test('returns null for non-info lines', () {
      expect(parseUciInfoLine('bestmove c3c4 ponder g6g5'), isNull);
    });
  });

  group('lastSearchInfo', () {
    test('picks the last (deepest) info line with a score', () {
      final log = [
        'info depth 5 score cp 10 pv a0a1',
        'info depth 10 score cp 37 pv h2e2 h9g7',
        'info string not a score line',
        'bestmove h2e2',
      ];
      final info = lastSearchInfo(log);
      expect(info!.score, 37);
      expect(info.pv.first, const XqMove(7, 2, 4, 2));
    });

    test('returns null when the log has no score lines', () {
      expect(lastSearchInfo(['uciok', 'readyok']), isNull);
    });
  });
}
