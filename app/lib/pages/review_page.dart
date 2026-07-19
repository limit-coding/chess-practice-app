// Steps 2.3-2.5: shows the score curve + move list for a finished game,
// lets the user rewind to any position, and — for the human's own
// sub-optimal moves — offers the engine's recommended move as a hint the
// user can play and keep practicing from.
import 'package:flutter/material.dart';

import '../engine/rapfi_ffi.dart';
import '../game/game_record.dart';
import '../game/game_review.dart';
import '../game/game_state.dart';
import '../game/stone.dart';
import '../widgets/board_view.dart';
import '../widgets/score_curve.dart';

/// Returned when the user chooses to keep playing from a rewound position —
/// [GamePage] adopts [game] as its live state.
class ResumeResult {
  const ResumeResult(this.game);
  final GomokuGame game;
}

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.record});

  final GameRecord record;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  static const _reviewer = GameReviewer();

  GameReview? _review;
  int _done = 0;
  int _total = 1;
  int? _selectedPly;
  bool _resuming = false;

  @override
  void initState() {
    super.initState();
    _runReview();
  }

  Future<void> _runReview() async {
    final review = await _reviewer.review(
      widget.record,
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() {
          _done = done;
          _total = total;
        });
      },
    );
    if (!mounted) return;
    setState(() => _review = review);
  }

  Future<void> _continueFromHint(int ply, (int, int) hintMove) async {
    final record = widget.record;
    setState(() => _resuming = true);
    try {
      final game = GomokuGame.replay(record.boardSize, record.moves.sublist(0, ply));
      game.play(hintMove.$1, hintMove.$2);

      RapfiEngine.instance.setSearchBudget(
        thinkMs: record.difficulty.thinkMs,
        maxDepth: record.difficulty.maxDepth,
      );
      final (engineMove, log) = await RapfiEngine.instance.setBoard(game.moves);

      if (engineMove == null || !RegExp(r'^\d+,\d+$').hasMatch(engineMove)) {
        final errorLine = log.firstWhere((l) => l.startsWith('ERROR'), orElse: () => '');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(errorLine.isNotEmpty ? '引擎错误: $errorLine' : '引擎未响应（超时），请重试'),
          ));
        }
        return;
      }

      final parts = engineMove.split(',');
      game.play(int.parse(parts[0]), int.parse(parts[1]));

      if (mounted) Navigator.of(context).pop(ResumeResult(game));
    } finally {
      if (mounted) setState(() => _resuming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = _review;
    return Scaffold(
      appBar: AppBar(title: const Text('复盘')),
      body: review == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text('引擎逐步评估中… ($_done/$_total)'),
                ],
              ),
            )
          : _ReviewBody(
              review: review,
              selectedPly: _selectedPly,
              resuming: _resuming,
              onSelectPly: (ply) => setState(() => _selectedPly = ply),
              onContinueFromHint: _continueFromHint,
            ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({
    required this.review,
    required this.selectedPly,
    required this.resuming,
    required this.onSelectPly,
    required this.onContinueFromHint,
  });

  final GameReview review;
  final int? selectedPly;
  final bool resuming;
  final ValueChanged<int> onSelectPly;
  final void Function(int ply, (int, int) hintMove) onContinueFromHint;

  @override
  Widget build(BuildContext context) {
    final record = review.record;
    final selected = selectedPly;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScoreCurve(
            curve: review.blackPovCurve,
            selectedPly: selected,
            onSelectPly: onSelectPly,
          ),
          const SizedBox(height: 8),
          if (selected != null)
            _PositionPreview(
              record: record,
              review: review,
              ply: selected,
              resuming: resuming,
              onContinueFromHint: onContinueFromHint,
            ),
          const Divider(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: review.moveReviews.length,
              itemBuilder: (context, i) {
                final mr = review.moveReviews[i];
                final isSelected = mr.ply == selected;
                return ListTile(
                  selected: isSelected,
                  leading: CircleAvatar(
                    backgroundColor: _qualityColor(mr.quality),
                    foregroundColor: Colors.white,
                    child: Text('${mr.ply + 1}', style: const TextStyle(fontSize: 12)),
                  ),
                  title: Text(
                    '${mr.move.stone == Stone.black ? "黑" : "白"} '
                    '(${mr.move.x},${mr.move.y})',
                  ),
                  trailing: Text(
                    mr.quality.label,
                    style: TextStyle(
                      color: _qualityColor(mr.quality),
                      fontWeight: mr.quality == MoveQuality.mistake ||
                              mr.quality == MoveQuality.blunder
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  onTap: () => onSelectPly(mr.ply),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Color _qualityColor(MoveQuality q) {
  return switch (q) {
    MoveQuality.best => Colors.green.shade700,
    MoveQuality.good => Colors.lightGreen.shade600,
    MoveQuality.inaccuracy => Colors.amber.shade700,
    MoveQuality.mistake => Colors.orange.shade800,
    MoveQuality.blunder => Colors.red.shade700,
  };
}

class _PositionPreview extends StatelessWidget {
  const _PositionPreview({
    required this.record,
    required this.review,
    required this.ply,
    required this.resuming,
    required this.onContinueFromHint,
  });

  final GameRecord record;
  final GameReview review;
  final int ply;
  final bool resuming;
  final void Function(int ply, (int, int) hintMove) onContinueFromHint;

  @override
  Widget build(BuildContext context) {
    // "退回到该局面" (2.4): the position right before this move was played,
    // reconstructed purely by local replay so it's guaranteed to match the
    // real game exactly.
    final game = GomokuGame.replay(record.boardSize, record.moves.sublist(0, ply));
    final playedMove = record.moves[ply];
    final mr = review.moveReviews.where((m) => m.ply == ply).firstOrNull;
    final beforeEval = review.evals[ply];
    final hint = beforeEval?.bestLine.isNotEmpty == true ? beforeEval!.bestLine.first : null;
    final isHumanMove = playedMove.stone == record.humanStone;
    final canHint = isHumanMove &&
        hint != null &&
        hint != (playedMove.x, playedMove.y) &&
        mr != null &&
        mr.quality != MoveQuality.best;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '第 ${ply + 1} 手前的局面'
          '${mr != null ? "（这手棋：${mr.quality.label}，损失约 ${mr.loss}）" : ""}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 220,
          child: Center(
            child: BoardView(
              boardSize: game.boardSize,
              board: game.board,
              lastMove: (playedMove.x, playedMove.y),
              hintMove: canHint ? hint : null,
            ),
          ),
        ),
        if (canHint)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '引擎推荐: (${hint.$1},${hint.$2})（棋盘上蓝色虚线圈），'
                    '实际下在 (${playedMove.x},${playedMove.y})',
                  ),
                ),
                FilledButton(
                  onPressed: resuming ? null : () => onContinueFromHint(ply, hint),
                  child: Text(resuming ? '同步中…' : '按提示继续练习'),
                ),
              ],
            ),
          )
        else if (!isHumanMove)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('这是引擎自己的应对，仅供参考。', style: TextStyle(color: Colors.black54)),
          ),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
