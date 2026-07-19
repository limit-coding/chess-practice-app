import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'difficulty.dart';
import 'game_state.dart';
import 'move_record.dart';
import 'stone.dart';

/// One finished (or in-progress) game, ready to be written to / read back
/// from disk — the raw data step 2 (复盘) will replay through the engine.
class GameRecord {
  const GameRecord({
    required this.boardSize,
    required this.difficulty,
    required this.startedAt,
    required this.moves,
    required this.winner,
    this.humanStone = Stone.black,
  });

  final int boardSize;
  final Difficulty difficulty;
  final DateTime startedAt;
  final List<MoveRecord> moves;
  final Stone? winner;

  /// Which color the human played — black (moves first) unless the human
  /// chose to let the engine open the game (step 1.3's "谁先手" option).
  final Stone humanStone;

  factory GameRecord.fromGame(
    GomokuGame game, {
    required Difficulty difficulty,
    required DateTime startedAt,
    Stone humanStone = Stone.black,
  }) =>
      GameRecord(
        boardSize: game.boardSize,
        difficulty: difficulty,
        startedAt: startedAt,
        moves: List.unmodifiable(game.moves),
        winner: game.winner,
        humanStone: humanStone,
      );

  Map<String, dynamic> toJson() => {
        'boardSize': boardSize,
        'difficulty': difficulty.name,
        'startedAt': startedAt.toIso8601String(),
        'winner': winner?.name,
        'humanStone': humanStone.name,
        'moves': moves.map((m) => m.toJson()).toList(),
      };

  factory GameRecord.fromJson(Map<String, dynamic> json) => GameRecord(
        boardSize: json['boardSize'] as int,
        difficulty: Difficulty.values.byName(json['difficulty'] as String),
        startedAt: DateTime.parse(json['startedAt'] as String),
        winner: json['winner'] == null
            ? null
            : Stone.values.byName(json['winner'] as String),
        // Older saved games predate this field — they were always
        // human-plays-black.
        humanStone: json['humanStone'] == null
            ? Stone.black
            : Stone.values.byName(json['humanStone'] as String),
        moves: (json['moves'] as List)
            .map((m) => MoveRecord.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

/// Persists [GameRecord]s as one JSON file per game under the app's
/// documents directory (`games/`), so a finished game's full move sequence
/// can be read back later (review, in step 2, or just debugging).
class GameRecordStore {
  /// [documentsDirOverride] lets tests point the store at a temp directory
  /// instead of going through the path_provider platform channel.
  const GameRecordStore({this.documentsDirOverride});

  final Future<Directory> Function()? documentsDirOverride;

  Future<Directory> _gamesDir() async {
    final docs = documentsDirOverride != null
        ? await documentsDirOverride!()
        : await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/games');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _fileNameFor(DateTime startedAt) =>
      'game_${startedAt.toIso8601String().replaceAll(RegExp(r'[:.]'), '-')}.json';

  Future<File> save(GameRecord record) async {
    final dir = await _gamesDir();
    final file = File('${dir.path}/${_fileNameFor(record.startedAt)}');
    await file.writeAsString(jsonEncode(record.toJson()));
    return file;
  }

  Future<GameRecord> load(File file) async {
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return GameRecord.fromJson(json);
  }

  /// Lists saved game files, most recent first.
  Future<List<File>> listGames() async {
    final dir = await _gamesDir();
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }
}
