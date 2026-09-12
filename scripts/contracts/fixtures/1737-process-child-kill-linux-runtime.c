#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

extern bool sollang_probe_kill(uint64_t token);

int main(void) {
    int passed = 0;
    if (!sollang_probe_kill(0)) {
        passed++;
    }

    pid_t child = fork();
    if (child < 0) {
        return 1;
    }
    if (child == 0) {
        for (;;) {
            pause();
        }
    }

    if (sollang_probe_kill((uint64_t)child)) {
        passed++;
    }
    int status = 0;
    if (waitpid(child, &status, 0) == child && WIFSIGNALED(status) && WTERMSIG(status) == 9) {
        passed++;
    }

    if (passed != 3) {
        return 2;
    }
    puts("process kill linux runtime: 3/3");
    return 0;
}
