import 'dart:io';

import 'package:chess_practice/game/difficulty.dart';
import 'package:chess_practice/game/game_record.dart';
import 'package:chess_practice/game/game_state.dart';
import 'package:chess_practice/game/stone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a finished game can be saved and its full move sequence read back', () async {
    final tempDir = await Directory.systemTemp.createTemp('game_record_test');
    addTearDown(() => tempDir.delete(recursive: true));

    final store = GameRecordStore(documentsDirOverride: () async => tempDir);

    final game = GomokuGame(boardSize: 15);
    final played = [(7, 7), (7, 8), (8, 7), (8, 8), (6, 7)];
    for (final (x, y) in played) {
      game.play(x, y);
    }
    final startedAt = DateTime(2026, 7, 19, 12, 0, 0);

    final file = await store.save(GameRecord.fromGame(
      game,
      difficulty: Difficulty.hard,
      startedAt: startedAt,
    ));

    expect(await file.exists(), isTrue);

    final loaded = await store.load(file);
    expect(loaded.boardSize, 15);
    expect(loaded.difficulty, Difficulty.hard);
    expect(loaded.startedAt, startedAt);
    expect(loaded.winner, game.winner);
    expect(loaded.moves.length, played.length);
    for (var i = 0; i < played.length; i++) {
      final (x, y) = played[i];
      expect(loaded.moves[i].x, x);
      expect(loaded.moves[i].y, y);
      expect(loaded.moves[i].stone, i.isEven ? Stone.black : Stone.white);
    }

    final listed = await store.listGames();
    expect(listed.map((f) => f.path), contains(file.path));
  });

  test('humanStone round-trips through save/load, defaulting to black', () async {
    final tempDir = await Directory.systemTemp.createTemp('game_record_test');
    addTearDown(() => tempDir.delete(recursive: true));
    final store = GameRecordStore(documentsDirOverride: () async => tempDir);

    final game = GomokuGame(boardSize: 15)..play(7, 7);
    final record = GameRecord.fromGame(
      game,
      difficulty: Difficulty.easy,
      startedAt: DateTime(2026, 7, 19),
      humanStone: Stone.white,
    );

    expect(record.humanStone, Stone.white);
    final file = await store.save(record);
    final loaded = await store.load(file);
    expect(loaded.humanStone, Stone.white);
  });

  test('a saved-before-this-field JSON blob defaults humanStone to black', () {
    final json = {
      'boardSize': 15,
      'difficulty': 'normal',
      'startedAt': DateTime(2026, 7, 19).toIso8601String(),
      'winner': null,
      'moves': <dynamic>[],
      // no 'humanStone' key — matches records saved before this field existed
    };
    expect(GameRecord.fromJson(json).humanStone, Stone.black);
  });
}
