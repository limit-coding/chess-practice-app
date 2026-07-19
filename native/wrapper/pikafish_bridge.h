/*
 * pikafish_bridge - C ABI wrapper around the Pikafish Xiangqi engine (GPLv3).
 *
 * Pikafish speaks the standard UCI protocol over stdin/stdout (see
 * https://backscattering.de/chess/uci/). Same architecture as
 * rapfi_bridge.h: the engine's UCI loop runs on a dedicated thread inside
 * the host process, with the C++ stream buffers swapped for thread-safe
 * in-memory pipes — not dup2() on the process-wide file descriptors, so the
 * host app's own stdio is untouched. Both bridges can run in the same
 * process; their symbols and internal state are independent.
 *
 * Typical session:
 *   pikafish_start();
 *   pikafish_send("uci");                                -> recv lines up to "uciok"
 *   pikafish_send("setoption name EvalFile value <path>"); (no reply)
 *   pikafish_send("isready");                             -> recv "readyok"
 *   pikafish_send("position startpos");                    (no reply)
 *   pikafish_send("go movetime 1000");                    -> recv lines up to "bestmove ..."
 */
#ifndef PIKAFISH_BRIDGE_H
#define PIKAFISH_BRIDGE_H

#define PIKAFISH_EXPORT __attribute__((used)) __attribute__((visibility("default")))

#ifdef __cplusplus
extern "C" {
#endif

/* Start the engine thread. Safe to call once per process. Returns 0 on
 * success, nonzero if the engine is already running. */
PIKAFISH_EXPORT int pikafish_start(void);

/* Send one protocol line to the engine ('\n' is appended automatically). */
PIKAFISH_EXPORT void pikafish_send(const char *line);

/* Block until the engine emits one output line or timeout_ms elapses.
 * The line (without trailing '\n') is copied into buf, NUL-terminated.
 * Returns the line length, or -1 on timeout, or -2 if buf is too small. */
PIKAFISH_EXPORT int pikafish_recv(char *buf, int buf_capacity, int timeout_ms);

#ifdef __cplusplus
}
#endif

#endif /* PIKAFISH_BRIDGE_H */
