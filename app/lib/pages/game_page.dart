// Phase 1 MVP: human vs Rapfi engine on a 15x15 board, with difficulty
// selection, choice of who moves first, and per-game persistence.
import 'package:flutter/material.dart';

import '../engine/rapfi_ffi.dart';
import '../game/difficulty.dart';
import '../game/game_record.dart';
import '../game/game_state.dart';
import '../game/stone.dart';
import '../widgets/board_view.dart';
import 'review_page.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  static const _boardSize = 15;
  static const _store = GameRecordStore();

  GomokuGame? _game;
  Difficulty _difficulty = Difficulty.normal;
  Stone _humanStone = Stone.black;
  DateTime? _startedAt;
  bool _busy = false;
  String? _status;
  GameRecord? _lastRecord;

  bool get _inGame => _game != null;

  String _yourTurnStatus() =>
      '轮到你落子（${_humanStone == Stone.black ? "黑棋" : "白棋"}）';

  Future<void> _startNewGame() async {
    setState(() {
      _busy = true;
      _status = '引擎准备中…';
    });
    await RapfiEngine.instance.startGame(
      boardSize: _boardSize,
      thinkMs: _difficulty.thinkMs,
      maxDepth: _difficulty.maxDepth,
    );

    final game = GomokuGame(boardSize: _boardSize);
    if (_humanStone == Stone.white) {
      // Engine plays black and opens the game.
      final (move, log) = await RapfiEngine.instance.engineOpens();
      final errorLine = log.firstWhere((l) => l.startsWith('ERROR'), orElse: () => '');
      if (move == null || !RegExp(r'^\d+,\d+$').hasMatch(move)) {
        setState(() {
          _busy = false;
          _status = errorLine.isNotEmpty ? '引擎错误: $errorLine' : '引擎未响应（超时）';
        });
        return;
      }
      final parts = move.split(',');
      game.play(int.parse(parts[0]), int.parse(parts[1]));
    }

    setState(() {
      _game = game;
      _startedAt = DateTime.now();
      _lastRecord = null;
      _busy = false;
      _status = _yourTurnStatus();
    });
  }

  Future<void> _onTapCell(int x, int y) async {
    final game = _game;
    if (game == null || _busy || game.isOver) return;
    if (game.turn != _humanStone) return; // engine's turn
    if (!game.canPlay(x, y)) return;

    setState(() {
      game.play(x, y);
      _busy = true;
      _status = '引擎思考中…';
    });

    if (game.isOver) {
      await _finishGame();
      return;
    }

    final (move, log) = await RapfiEngine.instance.reply(x, y);
    final errorLine = log.firstWhere(
      (l) => l.startsWith('ERROR'),
      orElse: () => '',
    );

    if (move == null || !RegExp(r'^\d+,\d+$').hasMatch(move)) {
      setState(() {
        _busy = false;
        _status = errorLine.isNotEmpty ? '引擎错误: $errorLine' : '引擎未响应（超时）';
      });
      return;
    }

    final parts = move.split(',');
    final ex = int.parse(parts[0]);
    final ey = int.parse(parts[1]);

    setState(() {
      game.play(ex, ey);
      _busy = false;
      _status = game.isOver ? null : _yourTurnStatus();
    });

    if (game.isOver) await _finishGame();
  }

  Future<void> _finishGame() async {
    final game = _game!;
    final record = GameRecord.fromGame(
      game,
      difficulty: _difficulty,
      startedAt: _startedAt!,
      humanStone: _humanStone,
    );
    await _store.save(record);
    setState(() {
      _lastRecord = record;
      _status = switch (game.winner) {
        null => '平局。',
        final w => w == _humanStone ? '你赢了！' : '引擎赢了。',
      };
    });
  }

  Future<void> _openReview() async {
    final record = _lastRecord;
    if (record == null) return;
    final result = await Navigator.of(context).push<ResumeResult>(
      MaterialPageRoute(builder: (_) => ReviewPage(record: record)),
    );
    if (result == null || !mounted) return;
    setState(() {
      _game = result.game;
      _difficulty = record.difficulty;
      _humanStone = record.humanStone;
      _startedAt = DateTime.now();
      _lastRecord = null;
      _busy = false;
      _status = _yourTurnStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return Scaffold(
      appBar: AppBar(title: const Text('五子棋练习')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              if (!_inGame) ...[
                _DifficultyPicker(
                  value: _difficulty,
                  onChanged: _busy ? null : (d) => setState(() => _difficulty = d),
                ),
                const SizedBox(height: 8),
                _FirstMoverPicker(
                  value: _humanStone,
                  onChanged: _busy ? null : (s) => setState(() => _humanStone = s),
                ),
              ],
              const SizedBox(height: 8),
              Text(_status ?? (_inGame ? '' : '选择难度和先后手后开始对局'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (game != null)
                Expanded(
                  child: Center(
                    child: BoardView(
                      boardSize: game.boardSize,
                      board: game.board,
                      lastMove: game.moves.isEmpty
                          ? null
                          : (game.moves.last.x, game.moves.last.y),
                      winningLine: game.winningLine,
                      onTapCell: _onTapCell,
                    ),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (game != null && game.isOver && _lastRecord != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: OutlinedButton(
                        onPressed: _openReview,
                        child: const Text('复盘'),
                      ),
                    ),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : () {
                              if (game == null || game.isOver) {
                                _startNewGame();
                              } else {
                                setState(() {
                                  _game = null;
                                  _status = null;
                                });
                              }
                            },
                      child: Text(game == null
                          ? '开始对局'
                          : game.isOver
                              ? '再来一局'
                              : '放弃对局'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirstMoverPicker extends StatelessWidget {
  const _FirstMoverPicker({required this.value, required this.onChanged});

  final Stone value;
  final ValueChanged<Stone>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<Stone>(
      segments: const [
        ButtonSegment(value: Stone.black, label: Text('我先手')),
        ButtonSegment(value: Stone.white, label: Text('AI先手')),
      ],
      selected: {value},
      onSelectionChanged: onChanged == null
          ? null
          : (s) => onChanged!(s.first),
    );
  }
}

class _DifficultyPicker extends StatelessWidget {
  const _DifficultyPicker({required this.value, required this.onChanged});

  final Difficulty value;
  final ValueChanged<Difficulty>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<Difficulty>(
      segments: Difficulty.values
          .map((d) => ButtonSegment(value: d, label: Text(d.label)))
          .toList(),
      selected: {value},
      onSelectionChanged: onChanged == null
          ? null
          : (s) => onChanged!(s.first),
    );
  }
}
