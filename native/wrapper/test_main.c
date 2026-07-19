/*
 * Step 0.4 acceptance test: drive the engine through the C bridge from
 * plain C, no C++ in this translation unit. Results go to stderr because
 * the engine owns the C++ side of stdout (C stdio is untouched, but we
 * keep the convention that the bridge's client logs to stderr).
 */
#include "rapfi_bridge.h"

#include <stdio.h>
#include <string.h>

static int expect_move(const char *ctx, int timeout_ms)
{
    char line[512];
    for (;;) {
        int n = rapfi_recv(line, sizeof line, timeout_ms);
        if (n < 0) {
            fprintf(stderr, "FAIL(%s): recv timeout/err %d\n", ctx, n);
            return -1;
        }
        fprintf(stderr, "  engine> %s\n", line);
        /* Skip informational lines; a move is "x,y". */
        if (strncmp(line, "MESSAGE", 7) == 0 || strncmp(line, "DEBUG", 5) == 0
            || strncmp(line, "ERROR", 5) == 0 || strncmp(line, "UNKNOWN", 7) == 0
            || strncmp(line, "OK", 2) == 0)
            continue;
        int x, y;
        if (sscanf(line, "%d,%d", &x, &y) == 2) {
            fprintf(stderr, "PASS(%s): engine move %d,%d\n", ctx, x, y);
            return 0;
        }
    }
}

int main(void)
{
    char line[512];

    if (rapfi_start() != 0) {
        fprintf(stderr, "FAIL: rapfi_start\n");
        return 1;
    }

    rapfi_send("START 15");
    if (rapfi_recv(line, sizeof line, 15000) < 0 || strncmp(line, "OK", 2) != 0) {
        fprintf(stderr, "FAIL: START 15 -> expected OK, got: %s\n", line);
        return 1;
    }
    fprintf(stderr, "PASS: START 15 -> OK\n");

    rapfi_send("INFO timeout_turn 3000");

    /* Engine opens the game. */
    rapfi_send("BEGIN");
    if (expect_move("BEGIN", 30000) != 0)
        return 1;

    /* Engine answers a human move. */
    rapfi_send("TURN 8,8");
    if (expect_move("TURN 8,8", 30000) != 0)
        return 1;

    rapfi_send("END");
    fprintf(stderr, "ALL PASS\n");
    return 0;
}
