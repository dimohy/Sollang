#ifndef _WIN32
#error This probe executes the Windows completion backend.
#endif

#include <stdint.h>
#include <stdio.h>
#include <windows.h>
#pragma comment(lib, "kernel32.lib")
#pragma comment(lib, "ws2_32.lib")

void *sollang_io_completion_head;
int64_t sollang_io_outstanding;
void *sollang_io_completion_event;
static unsigned unexpected_wakes;

/* No operation is submitted by this capacity/owner-lifetime probe. */
void sollang_task_enqueue_ready(void *control) {
    (void)control;
    ++unexpected_wakes;
}

extern int64_t socket_probe_create(uint64_t registrations, uint64_t pending,
                                   uint64_t batch, int32_t *kind, int32_t *code);
extern void sollang_platform_socket_completion_close(int64_t identity);
extern void sollang_async_shutdown(void);

int slg_program_main(void) {
    static const uint64_t invalid[][3] = {
        {0, 0, 0}, {0, 1, 1}, {1, 0, 1}, {1, 1, 0},
        {1025, 1, 1}, {1, 2, 1}, {2, 1, 2}, {UINT64_MAX, 1, 1}
    };
    DWORD before, after;
    if (!GetProcessHandleCount(GetCurrentProcess(), &before)) return 1;
    for (unsigned index = 0; index < sizeof invalid / sizeof invalid[0]; ++index) {
        int32_t kind = -1, code = -1;
        int64_t identity = socket_probe_create(invalid[index][0], invalid[index][1],
                                              invalid[index][2], &kind, &code);
        if (identity != -1 || kind != 1 || code != 0) return 2;
    }
    if (!GetProcessHandleCount(GetCurrentProcess(), &after) || before != after)
        return 3;

    for (unsigned round = 0; round < 8; ++round) {
        uint64_t capacity = round == 7 ? 1024 : (round % 4) + 1;
        int32_t kind = 0, code = -1;
        int64_t identity = socket_probe_create(capacity, capacity, capacity,
                                              &kind, &code);
        if (identity <= 0 || kind != -1 || code != 0) return 4;
        sollang_platform_socket_completion_close(identity);
        if (!GetProcessHandleCount(GetCurrentProcess(), &after) || before != after)
            return 5;
    }
    sollang_platform_socket_completion_close(0);
    sollang_async_shutdown();
    if (unexpected_wakes || sollang_io_outstanding ||
        sollang_io_completion_head || sollang_io_completion_event)
        return 6;
    puts("socket-completion-runtime-ok");
    return 0;
}

/* Reuse the existing allocator audit rather than a second bookkeeping path. */
#include "c437_allocation_audit.c"
