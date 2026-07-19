import 'package:chess_practice/game/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('higher difficulty gives the engine a strictly larger search budget', () {
    final levels = Difficulty.values; // declaration order: easy, normal, hard
    for (var i = 1; i < levels.length; i++) {
      expect(levels[i].thinkMs, greaterThan(levels[i - 1].thinkMs),
          reason: '${levels[i].label} 的思考时间应比 ${levels[i - 1].label} 长');
      expect(levels[i].maxDepth, greaterThanOrEqualTo(levels[i - 1].maxDepth),
          reason: '${levels[i].label} 的搜索深度不应比 ${levels[i - 1].label} 浅');
    }
  });
}
