/// Maps a user-facing difficulty choice to the engine's search budget.
///
/// Sent to Rapfi as `INFO TIMEOUT_TURN` and `INFO MAX_DEPTH` before each
/// game (thinkMs and maxDepth respectively) — a longer time budget and
/// deeper search cap both make the engine noticeably stronger.
enum Difficulty {
  easy(label: '简单', thinkMs: 300, maxDepth: 4),
  normal(label: '中等', thinkMs: 1500, maxDepth: 14),
  hard(label: '困难', thinkMs: 5000, maxDepth: 99);

  const Difficulty({
    required this.label,
    required this.thinkMs,
    required this.maxDepth,
  });

  final String label;
  final int thinkMs;
  final int maxDepth;
}
