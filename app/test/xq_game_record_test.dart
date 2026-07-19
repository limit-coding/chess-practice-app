import 'dart:io';

import 'package:chess_practice/game/difficulty.dart';
import 'package:chess_practice/xiangqi/piece.dart';
import 'package:chess_practice/xiangqi/xiangqi_game.dart';
import 'package:chess_practice/xiangqi/xq_game_record.dart';
import 'package:chess_practice/xiangqi/xq_move.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a finished game can be saved and its full move sequence read back', () async {
    final tempDir = await Directory.systemTemp.createTemp('xq_game_record_test');
    addTearDown(() => tempDir.delete(recursive: true));
    final store = XqGameRecordStore(documentsDirOverride: () async => tempDir);

    final game = XiangqiGame();
    final played = [
      const XqMove(7, 2, 4, 2), // red cannon h2e2
      const XqMove(1, 7, 4, 7), // black cannon b7e7
    ];
    for (final m in played) {
      game.play(m);
    }
    final startedAt = DateTime(2026, 7, 19, 12, 0, 0);

    final record = XqGameRecord.fromGame(
      game,
      difficulty: Difficulty.hard,
      startedAt: startedAt,
      humanSide: Side.black,
    );
    final file = await store.save(record);

    expect(await file.exists(), isTrue);

    final loaded = await store.load(file);
    expect(loaded.difficulty, Difficulty.hard);
    expect(loaded.startedAt, startedAt);
    expect(loaded.humanSide, Side.black);
    expect(loaded.winner, game.winner);
    expect(loaded.moves.length, played.length);
    for (var i = 0; i < played.length; i++) {
      expect(loaded.moves[i].fromX, played[i].fromX);
      expect(loaded.moves[i].fromY, played[i].fromY);
      expect(loaded.moves[i].toX, played[i].toX);
      expect(loaded.moves[i].toY, played[i].toY);
      expect(loaded.moves[i].side, i.isEven ? Side.red : Side.black);
    }

    final listed = await store.listGames();
    expect(listed.map((f) => f.path), contains(file.path));
  });

  test('a saved-before-humanSide JSON blob defaults humanSide to red', () {
    final json = {
      'difficulty': 'normal',
      'startedAt': DateTime(2026, 7, 19).toIso8601String(),
      'winner': null,
      'moves': <dynamic>[],
    };
    expect(XqGameRecord.fromJson(json).humanSide, Side.red);
  });
}
