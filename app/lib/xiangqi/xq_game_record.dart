import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../game/difficulty.dart';
import 'piece.dart';
import 'xiangqi_game.dart';
import 'xq_move_record.dart';

/// One finished (or in-progress) Xiangqi game — the Xiangqi analogue of
/// game/game_record.dart's `GameRecord`. Kept as a separate type rather
/// than sharing `GameRecord` because the two games' move/position
/// representations aren't compatible (coordinates vs. board-square pairs).
class XqGameRecord {
  const XqGameRecord({
    required this.difficulty,
    required this.startedAt,
    required this.moves,
    required this.winner,
    required this.humanSide,
  });

  final Difficulty difficulty;
  final DateTime startedAt;
  final List<XqMoveRecord> moves;
  final Side? winner;
  final Side humanSide;

  factory XqGameRecord.fromGame(
    XiangqiGame game, {
    required Difficulty difficulty,
    required DateTime startedAt,
    required Side humanSide,
  }) =>
      XqGameRecord(
        difficulty: difficulty,
        startedAt: startedAt,
        moves: List.unmodifiable(game.moves),
        winner: game.winner,
        humanSide: humanSide,
      );

  Map<String, dynamic> toJson() => {
        'difficulty': difficulty.name,
        'startedAt': startedAt.toIso8601String(),
        'winner': winner?.name,
        'humanSide': humanSide.name,
        'moves': moves.map((m) => m.toJson()).toList(),
      };

  factory XqGameRecord.fromJson(Map<String, dynamic> json) => XqGameRecord(
        difficulty: Difficulty.values.byName(json['difficulty'] as String),
        startedAt: DateTime.parse(json['startedAt'] as String),
        winner: json['winner'] == null
            ? null
            : Side.values.byName(json['winner'] as String),
        humanSide: json['humanSide'] == null
            ? Side.red
            : Side.values.byName(json['humanSide'] as String),
        moves: (json['moves'] as List)
            .map((m) => XqMoveRecord.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

/// Persists [XqGameRecord]s as one JSON file per game under the app's
/// documents directory (`xiangqi_games/`) — same shape as
/// game/game_record.dart's `GameRecordStore`, kept separate so the two
/// games' saved games never collide in one directory.
class XqGameRecordStore {
  const XqGameRecordStore({this.documentsDirOverride});

  final Future<Directory> Function()? documentsDirOverride;

  Future<Directory> _gamesDir() async {
    final docs = documentsDirOverride != null
        ? await documentsDirOverride!()
        : await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/xiangqi_games');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _fileNameFor(DateTime startedAt) =>
      'xiangqi_${startedAt.toIso8601String().replaceAll(RegExp(r'[:.]'), '-')}.json';

  Future<File> save(XqGameRecord record) async {
    final dir = await _gamesDir();
    final file = File('${dir.path}/${_fileNameFor(record.startedAt)}');
    await file.writeAsString(jsonEncode(record.toJson()));
    return file;
  }

  Future<XqGameRecord> load(File file) async {
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return XqGameRecord.fromJson(json);
  }

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
