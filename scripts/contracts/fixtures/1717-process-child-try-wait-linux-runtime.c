#include <stdint.h>
#include <stdio.h>
#include <signal.h>
#include <unistd.h>

extern uint64_t sollang_probe_poll(uint64_t token);
extern uint64_t sollang_probe_wait(uint64_t token);

static int state(uint64_t packed) { return (int)(packed >> 32); }
static int code(uint64_t packed) { return (int)(uint32_t)packed; }

static uint64_t await_exit(int child) {
    uint64_t result = 0;
    for (int attempt = 0; attempt < 400; ++attempt) {
        result = sollang_probe_poll((uint64_t)child);
        if (state(result) != 0) return result;
        usleep(10000);
    }
    return result;
}

int main(void) {
    int barrier[2];
    if (pipe(barrier) != 0) return 1;
    int slow = fork();
    if (slow == 0) {
        char released;
        close(barrier[1]);
        if (read(barrier[0], &released, 1) != 1) _exit(99);
        _exit(7);
    }
    close(barrier[0]);
    if (slow < 0 || state(sollang_probe_poll((uint64_t)slow)) != 0) return 1;
    if (write(barrier[1], "x", 1) != 1) return 2;
    close(barrier[1]);
    uint64_t finished = await_exit(slow);
    if (state(finished) != 1 || code(finished) != 7) return 2;
    if (state(sollang_probe_poll((uint64_t)slow)) != 2) return 3;
    if (state(sollang_probe_poll(0)) != 2) return 4;

    int signaled = fork();
    if (signaled == 0) { for (;;) pause(); }
    if (signaled < 0 || kill(signaled, SIGTERM) != 0) return 5;
    uint64_t signal_result = await_exit(signaled);
    if (state(signal_result) != 3 || code(signal_result) != 0) return 6;
    if (state(sollang_probe_poll((uint64_t)signaled)) != 2) return 7;

    int direct = fork();
    if (direct == 0) { for (;;) pause(); }
    if (direct < 0 || kill(direct, SIGTERM) != 0) return 8;
    uint64_t direct_result = sollang_probe_wait((uint64_t)direct);
    if (state(direct_result) != 3 || code(direct_result) != 0) return 9;
    puts("process tryWait linux runtime: 8/8");
    return 0;
}
