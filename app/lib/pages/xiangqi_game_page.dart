// Step 4.2: human vs Pikafish on a 9x10 Xiangqi board — select-then-move
// interaction, difficulty selection, choice of who moves first (Red always
// moves first, same convention as Gomoku's black).
import 'package:flutter/material.dart';

import '../engine/pikafish_assets.dart';
import '../engine/pikafish_ffi.dart';
import '../game/difficulty.dart';
import '../widgets/xiangqi_board_view.dart';
import '../xiangqi/piece.dart';
import '../xiangqi/xiangqi_game.dart';
import '../xiangqi/xq_move.dart';

class XiangqiGamePage extends StatefulWidget {
  const XiangqiGamePage({super.key});

  @override
  State<XiangqiGamePage> createState() => _XiangqiGamePageState();
}

class _XiangqiGamePageState extends State<XiangqiGamePage> {
  XiangqiGame? _game;
  Difficulty _difficulty = Difficulty.normal;
  Side _humanSide = Side.red;
  (int, int)? _selected;
  bool _busy = false;
  bool _engineReady = false;
  String? _status;

  bool get _inGame => _game != null;

  String _turnStatus() =>
      '轮到你走子（${_humanSide == Side.red ? "红方" : "黑方"}）';

  Future<void> _ensureEngineReady() async {
    if (_engineReady) return;
    final evalFile = await const PikafishAssets().ensureNetworkFile();
    await PikafishEngine.instance.start(evalFile: evalFile);
    _engineReady = true;
  }

  Future<void> _startNewGame() async {
    setState(() {
      _busy = true;
      _status = '引擎准备中…';
    });
    await _ensureEngineReady();
    PikafishEngine.instance.newGame();

    setState(() {
      _game = XiangqiGame();
      _selected = null;
      _busy = false;
      _status = _turnStatus();
    });
    await _maybeEngineMove();
  }

  Future<void> _maybeEngineMove() async {
    final game = _game;
    if (game == null || game.isOver || game.turn == _humanSide) return;

    setState(() {
      _busy = true;
      _status = '引擎思考中…';
    });

    final uciMoves = game.moves
        .map((m) => XqMove(m.fromX, m.fromY, m.toX, m.toY).uci)
        .toList();
    PikafishEngine.instance.setPosition(moves: uciMoves);
    final (bestMoveUci, _, log) =
        await PikafishEngine.instance.goMoveTime(_difficulty.thinkMs);
    final move = bestMoveUci == null ? null : XqMove.fromUci(bestMoveUci);

    if (move == null) {
      setState(() {
        _busy = false;
        _status = '引擎错误或未响应（$log）';
      });
      return;
    }

    setState(() {
      game.play(move);
      _busy = false;
      _status = game.isOver ? null : _turnStatus();
    });

    if (game.isOver) _finishGame();
  }

  void _finishGame() {
    final game = _game!;
    setState(() {
      _status = switch (game.winner) {
        null => '和棋。', // unreachable in Xiangqi (no legal moves = a loss), kept for completeness
        final w when w == _humanSide => '你赢了！',
        _ => '引擎赢了。',
      };
    });
  }

  void _onTapCell(int x, int y) {
    final game = _game;
    if (game == null || _busy || game.isOver || game.turn != _humanSide) return;

    final selected = _selected;
    if (selected != null) {
      final move = XqMove(selected.$1, selected.$2, x, y);
      if (game.canPlay(move)) {
        setState(() {
          game.play(move);
          _selected = null;
        });
        if (game.isOver) {
          _finishGame();
        } else {
          _maybeEngineMove();
        }
        return;
      }
    }

    final piece = game.board.at(x, y);
    setState(() {
      _selected = (piece != null && piece.side == _humanSide) ? (x, y) : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final legalDestinations = (game != null && _selected != null)
        ? game.board
            .legalMovesFrom(_selected!.$1, _selected!.$2)
            .map((m) => (m.toX, m.toY))
            .toList()
        : const <(int, int)>[];

    return Scaffold(
      appBar: AppBar(title: const Text('象棋练习')),
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
                  value: _humanSide,
                  onChanged: _busy ? null : (s) => setState(() => _humanSide = s),
                ),
              ],
              const SizedBox(height: 8),
              Text(_status ?? (_inGame ? '' : '选择难度和红黑方后开始对局'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (game != null)
                Expanded(
                  child: Center(
                    child: XiangqiBoardView(
                      squares: game.board.squares,
                      selected: _selected,
                      legalDestinations: legalDestinations,
                      lastMove: game.moves.isEmpty
                          ? null
                          : (game.moves.last.toX, game.moves.last.toY),
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
                            _selected = null;
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

class _FirstMoverPicker extends StatelessWidget {
  const _FirstMoverPicker({required this.value, required this.onChanged});

  final Side value;
  final ValueChanged<Side>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<Side>(
      segments: const [
        ButtonSegment(value: Side.red, label: Text('我先手（红）')),
        ButtonSegment(value: Side.black, label: Text('AI先手（我执黑）')),
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
