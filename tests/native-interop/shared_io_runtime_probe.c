#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef _WIN32
#include <windows.h>
#pragma comment(lib, "kernel32.lib")
#endif

/* Match the production LLVM Task control ABI, including its completion link. */
typedef struct Control Control;
struct Control {
    void *context, *worker, *destroy, *ready_next;
    int32_t status, resume_state;
    void (*cancel)(Control *);
    Control *timer_next;
    int64_t deadline;
    void *waiter, *waiting_on;
    int32_t error, phase;
    int64_t descriptor, value;
    int32_t kind;
    Control *io_next;
    int64_t identity, offset;
    int32_t explicit_owner, requested;
};
_Static_assert(sizeof(Control) == 144, "Task control size");
_Static_assert(offsetof(Control, cancel) == 40, "Task cancel callback");
_Static_assert(offsetof(Control, phase) == 84, "Task completion phase");
_Static_assert(offsetof(Control, io_next) == 112, "Task completion link");

Control *sollang_io_completion_head;
int64_t sollang_io_outstanding;
#ifdef _WIN32
void *sollang_io_completion_event;
#else
int32_t sollang_io_completion_event_fd = -1;
#endif

extern bool sollang_platform_io_ensure_signal(void);
extern void sollang_io_push_completion(Control *control);
extern void sollang_platform_io_signal_completion(void);
extern bool sollang_file_drain_completions(void);
extern void sollang_file_wait_idle(void);
extern void sollang_async_shutdown(void);

static uintptr_t wake_order[32];
static unsigned wake_count, cancel_count;
static bool invalid_callback;

/* The queue test observes scheduler handoff without replacing its IO code. */
void sollang_task_enqueue_ready(Control *control) {
    if (wake_count >= 32) {
        invalid_callback = true;
        return;
    }
    wake_order[wake_count++] = (uintptr_t)control->context;
}

static void observe_cancel(Control *control) {
    if (control->phase != 3 || (uintptr_t)control->context != 3)
        invalid_callback = true;
    ++cancel_count;
}

/* Production IO workers publish first, then signal the scheduler separately. */
static void publish_completed(Control *control) {
    sollang_io_push_completion(control);
    sollang_platform_io_signal_completion();
}

int main(void) {
    for (unsigned round = 0; round < 8; ++round) {
#ifdef _WIN32
        DWORD handles_before, handles_after;
        if (!GetProcessHandleCount(GetCurrentProcess(), &handles_before))
            return 1;
#endif
        if (!sollang_platform_io_ensure_signal() ||
            !sollang_platform_io_ensure_signal())
            return 2;
        Control first = {0}, second = {0};
        Control *cancelled = calloc(1, sizeof *cancelled);
        if (!cancelled) return 3;
        first.context = (void *)(uintptr_t)1;
        second.context = (void *)(uintptr_t)2;
        cancelled->context = (void *)(uintptr_t)3;
        cancelled->phase = 3;
        cancelled->cancel = observe_cancel;
        wake_count = cancel_count = 0;
        invalid_callback = false;
        sollang_io_outstanding = 3;
        publish_completed(&first);
        publish_completed(&second);
        publish_completed(cancelled);
        if (!sollang_file_drain_completions() || wake_count != 2 ||
            wake_order[0] != 1 || wake_order[1] != 2 || cancel_count != 1 ||
            invalid_callback || sollang_io_outstanding != 0 ||
            sollang_io_completion_head || sollang_file_drain_completions())
            return 4;

        /* Exercise wait/drain, rather than only the already-idle fast path. */
        sollang_io_outstanding = 1;
        publish_completed(&first);
        sollang_file_wait_idle();
        if (wake_count != 3 || wake_order[2] != 1 ||
            sollang_io_outstanding != 0 || sollang_io_completion_head)
            return 5;
        sollang_async_shutdown();
        sollang_async_shutdown();
#ifdef _WIN32
        if (sollang_io_completion_event ||
            !GetProcessHandleCount(GetCurrentProcess(), &handles_after) ||
            handles_before != handles_after)
            return 6;
#else
        if (sollang_io_completion_event_fd != -1) return 6;
#endif
    }
    puts("shared-io-runtime-ok");
    return 0;
}
