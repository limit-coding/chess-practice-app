// Phase 1 MVP: human (black, moves first) vs Rapfi engine (white) on a
// 15x15 board, with difficulty selection and per-game persistence.
import 'package:flutter/material.dart';

import '../engine/rapfi_ffi.dart';
import '../game/difficulty.dart';
import '../game/game_record.dart';
import '../game/game_state.dart';
import '../game/stone.dart';
import '../widgets/board_view.dart';

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
  DateTime? _startedAt;
  bool _busy = false;
  String? _status;

  bool get _inGame => _game != null;

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
    setState(() {
      _game = GomokuGame(boardSize: _boardSize);
      _startedAt = DateTime.now();
      _busy = false;
      _status = '轮到你落子（黑棋）';
    });
  }

  Future<void> _onTapCell(int x, int y) async {
    final game = _game;
    if (game == null || _busy || game.isOver) return;
    if (game.turn != Stone.black) return; // engine's turn
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
      _status = game.isOver ? null : '轮到你落子（黑棋）';
    });

    if (game.isOver) await _finishGame();
  }

  Future<void> _finishGame() async {
    final game = _game!;
    await _store.save(GameRecord.fromGame(
      game,
      difficulty: _difficulty,
      startedAt: _startedAt!,
    ));
    setState(() {
      _status = switch (game.winner) {
        Stone.black => '你赢了！',
        Stone.white => '引擎赢了。',
        null => '平局。',
      };
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
              if (!_inGame) _DifficultyPicker(
                value: _difficulty,
                onChanged: _busy ? null : (d) => setState(() => _difficulty = d),
              ),
              const SizedBox(height: 8),
              Text(_status ?? (_inGame ? '' : '选择难度后开始对局'),
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
              FilledButton(
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
            ],
          ),
        ),
      ),
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
