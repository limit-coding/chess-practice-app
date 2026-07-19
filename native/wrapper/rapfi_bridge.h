/*
 * rapfi_bridge - C ABI wrapper around the Rapfi Gomoku engine (GPLv3).
 *
 * Rapfi speaks the Gomocup (piskvork) text protocol over stdin/stdout.
 * This bridge runs the engine's protocol loop on a dedicated thread inside
 * the host process and exposes a line-oriented send/recv API, so any
 * language with C interop (Swift, Dart FFI, ...) can drive the engine
 * without spawning a child process (required on iOS, where fork/exec of a
 * bundled binary is not allowed).
 *
 * Protocol reference: https://plastovicka.github.io/protocl2en.htm
 * Typical session:
 *   rapfi_start();
 *   rapfi_send("START 15");        -> recv "OK"
 *   rapfi_send("TURN 7,7");        -> recv "8,8" (engine move, may be
 *                                     preceded by MESSAGE/DEBUG lines)
 */
#ifndef RAPFI_BRIDGE_H
#define RAPFI_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

/* Start the engine thread. Safe to call once per process. Returns 0 on
 * success, nonzero if the engine is already running. */
int rapfi_start(void);

/* Send one protocol line to the engine ('\n' is appended automatically). */
void rapfi_send(const char *line);

/* Block until the engine emits one output line or timeout_ms elapses.
 * The line (without trailing '\n') is copied into buf, NUL-terminated.
 * Returns the line length, or -1 on timeout, or -2 if buf is too small. */
int rapfi_recv(char *buf, int buf_capacity, int timeout_ms);

#ifdef __cplusplus
}
#endif

#endif /* RAPFI_BRIDGE_H */
