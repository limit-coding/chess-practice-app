/*
 * Pikafish bridge smoke test: drive the UCI handshake through the C bridge
 * from plain C. Doesn't exercise a real search yet (needs the NNUE network
 * file wired up first) — this only proves the engine thread starts and
 * speaks UCI back over the swapped stdin/stdout streambufs.
 */
#include "pikafish_bridge.h"

#include <stdio.h>
#include <string.h>

static int expect_line(const char *ctx, const char *want_prefix, int timeout_ms)
{
    char line[1024];
    for (;;) {
        int n = pikafish_recv(line, sizeof line, timeout_ms);
        if (n < 0) {
            fprintf(stderr, "FAIL(%s): recv timeout/err %d\n", ctx, n);
            return -1;
        }
        fprintf(stderr, "  engine> %s\n", line);
        if (strncmp(line, want_prefix, strlen(want_prefix)) == 0) {
            fprintf(stderr, "PASS(%s)\n", ctx);
            return 0;
        }
    }
}

int main(void)
{
    if (pikafish_start() != 0) {
        fprintf(stderr, "FAIL: pikafish_start\n");
        return 1;
    }

    pikafish_send("uci");
    if (expect_line("uci -> uciok", "uciok", 15000) != 0)
        return 1;

    pikafish_send("isready");
    if (expect_line("isready -> readyok", "readyok", 15000) != 0)
        return 1;

    pikafish_send("position startpos");
    pikafish_send("go movetime 2000");
    if (expect_line("go movetime 2000 -> bestmove", "bestmove", 30000) != 0)
        return 1;

    fprintf(stderr, "ALL PASS\n");
    return 0;
}
