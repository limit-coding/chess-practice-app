// Step 4.3: Xiangqi analogue of pages/review_page.dart — score curve +
// move list for a finished game, rewind to any position, and (for the
// human's own sub-optimal moves) an engine hint the user can play and keep
// practicing from.
import 'package:flutter/material.dart';

import '../engine/pikafish_ffi.dart';
import '../widgets/score_curve.dart';
import '../widgets/xiangqi_board_view.dart';
import '../xiangqi/piece.dart';
import '../xiangqi/xiangqi_game.dart';
import '../xiangqi/xq_game_record.dart';
import '../xiangqi/xq_game_review.dart';
import '../xiangqi/xq_move.dart';

/// Returned when the user chooses to keep playing from a rewound position —
/// [XiangqiGamePage] adopts [game] as its live state.
class XqResumeResult {
  const XqResumeResult(this.game);
  final XiangqiGame game;
}

class XiangqiReviewPage extends StatefulWidget {
  const XiangqiReviewPage({super.key, required this.record});

  final XqGameRecord record;

  @override
  State<XiangqiReviewPage> createState() => _XiangqiReviewPageState();
}

class _XiangqiReviewPageState extends State<XiangqiReviewPage> {
  static const _reviewer = XqGameReviewer();

  XqGameReview? _review;
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

  Future<void> _continueFromHint(int ply, XqMove hint) async {
    final record = widget.record;
    setState(() => _resuming = true);
    try {
      final game = XiangqiGame.replay(record.moves.sublist(0, ply));
      game.play(hint);

      final uciMoves =
          game.moves.map((m) => XqMove(m.fromX, m.fromY, m.toX, m.toY).uci).toList();
      PikafishEngine.instance.setPosition(moves: uciMoves);
      final (bestMoveUci, _, log) =
          await PikafishEngine.instance.goMoveTime(record.difficulty.thinkMs);
      final move = bestMoveUci == null ? null : XqMove.fromUci(bestMoveUci);

      if (move == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('引擎未响应（超时），请重试：$log'),
          ));
        }
        return;
      }

      game.play(move);
      if (mounted) Navigator.of(context).pop(XqResumeResult(game));
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

  final XqGameReview review;
  final int? selectedPly;
  final bool resuming;
  final ValueChanged<int> onSelectPly;
  final void Function(int ply, XqMove hint) onContinueFromHint;

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
            curve: review.redPovCurve,
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
                    '${mr.move.side == Side.red ? "红" : "黑"} '
                    '(${mr.move.fromX},${mr.move.fromY})→(${mr.move.toX},${mr.move.toY})',
                  ),
                  trailing: Text(
                    mr.quality.label,
                    style: TextStyle(
                      color: _qualityColor(mr.quality),
                      fontWeight: mr.quality == XqMoveQuality.mistake ||
                              mr.quality == XqMoveQuality.blunder
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

Color _qualityColor(XqMoveQuality q) {
  return switch (q) {
    XqMoveQuality.best => Colors.green.shade700,
    XqMoveQuality.good => Colors.lightGreen.shade600,
    XqMoveQuality.inaccuracy => Colors.amber.shade700,
    XqMoveQuality.mistake => Colors.orange.shade800,
    XqMoveQuality.blunder => Colors.red.shade700,
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

  final XqGameRecord record;
  final XqGameReview review;
  final int ply;
  final bool resuming;
  final void Function(int ply, XqMove hint) onContinueFromHint;

  @override
  Widget build(BuildContext context) {
    final game = XiangqiGame.replay(record.moves.sublist(0, ply));
    final playedMove = record.moves[ply];
    final mr = review.moveReviews.where((m) => m.ply == ply).firstOrNull;
    final beforeEval = review.evals[ply];
    final hint = beforeEval?.pv.isNotEmpty == true ? beforeEval!.pv.first : null;
    final playedAsMove =
        XqMove(playedMove.fromX, playedMove.fromY, playedMove.toX, playedMove.toY);
    final isHumanMove = playedMove.side == record.humanSide;
    final canHint = isHumanMove &&
        hint != null &&
        hint != playedAsMove &&
        mr != null &&
        mr.quality != XqMoveQuality.best;

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
          height: 260,
          child: Center(
            child: XiangqiBoardView(
              squares: game.board.squares,
              lastMove: (playedMove.toX, playedMove.toY),
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
                    '引擎推荐: (${hint.fromX},${hint.fromY})→(${hint.toX},${hint.toY})'
                    '（棋盘上蓝色虚线圈），实际下在 (${playedMove.fromX},${playedMove.fromY})→'
                    '(${playedMove.toX},${playedMove.toY})',
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
