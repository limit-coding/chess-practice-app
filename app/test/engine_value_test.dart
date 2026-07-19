import 'package:chess_practice/game/engine_value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseEngineValue', () {
    test('plain integers', () {
      expect(parseEngineValue('138'), 138);
      expect(parseEngineValue('-52'), -52);
      expect(parseEngineValue('0'), 0);
    });

    test('mate notation', () {
      expect(parseEngineValue('+M3'), valueMate - 3);
      expect(parseEngineValue('-M3'), -(valueMate - 3));
      expect(parseEngineValue('+M1'), valueMate - 1);
    });

    test('mate-from-database and infinity edge cases', () {
      expect(parseEngineValue('+M*'), valueMate);
      expect(parseEngineValue('-M*'), -valueMate);
      expect(parseEngineValue('VAL_INF'), greaterThan(valueMate));
      expect(parseEngineValue('-VAL_INF'), lessThan(-valueMate));
    });

    test('unparseable tokens return null', () {
      expect(parseEngineValue('VAL_NONE'), isNull);
      expect(parseEngineValue('garbage'), isNull);
    });
  });

  group('parseEvalFromMessageLine', () {
    test('extracts the value from a search-end message line', () {
      const line = 'MESSAGE Speed 1039K | Depth 12-25 | Eval 100 | Node 22K | Time 22ms';
      expect(parseEvalFromMessageLine(line), 100);
    });

    test('extracts a mate value', () {
      const line = 'MESSAGE Speed 500K | Depth 8-20 | Eval +M3 | Node 10K | Time 5ms';
      expect(parseEvalFromMessageLine(line), valueMate - 3);
    });

    test('returns null when there is no Eval fragment', () {
      expect(parseEvalFromMessageLine('MESSAGE Bestline H8 G8'), isNull);
    });
  });

  group('parseLabelCoord', () {
    test('parses column letter + 1-indexed row', () {
      expect(parseLabelCoord('A1'), (0, 0));
      expect(parseLabelCoord('H8'), (7, 7));
      expect(parseLabelCoord('O15'), (14, 14));
    });

    test('is case-insensitive', () {
      expect(parseLabelCoord('h8'), (7, 7));
    });

    test('rejects non-coordinate tokens', () {
      expect(parseLabelCoord('Pass'), isNull);
      expect(parseLabelCoord(''), isNull);
      expect(parseLabelCoord('88'), isNull);
    });
  });

  group('parseBestlineFromMessageLine', () {
    test('parses a full principal variation in order', () {
      const line = 'MESSAGE Bestline H8 G8 I7 G9 H6';
      expect(parseBestlineFromMessageLine(line), [
        (7, 7),
        (6, 7),
        (8, 6),
        (6, 8),
        (7, 5),
      ]);
    });

    test('empty PV', () {
      expect(parseBestlineFromMessageLine('MESSAGE Bestline'), isEmpty);
    });

    test('lines without Bestline yield nothing', () {
      expect(parseBestlineFromMessageLine('MESSAGE Eval 100'), isEmpty);
    });
  });
}
