#include <stdint.h>
#include <stdio.h>
#include <string.h>

extern uint64_t sollang_probe_poll(uint64_t token);
extern uint64_t sollang_probe_poll_injected(uint64_t token);

static int actual_checks;
static int injected_checks;
static int poll_state(uint64_t value) { return (int)(value >> 32); }
static int poll_code(uint64_t value) { return (int)(uint32_t)value; }
static int check(int condition, const char *name, int injected) {
    if (!condition) { fprintf(stderr, "FAIL %s\n", name); return 0; }
    if (injected) ++injected_checks; else ++actual_checks;
    return 1;
}

#ifdef _WIN32
#include <windows.h>

static int wait_calls, read_calls, close_calls;
static int injected_wait, injected_read, injected_close;
int32_t sollang_probe_wait(void *handle, int32_t timeout) {
    ++wait_calls;
    if (handle != (void *)(uintptr_t)123 || timeout != 0) return -1;
    return injected_wait;
}
int32_t sollang_probe_read_exit(void *handle, uint32_t *code) {
    ++read_calls;
    if (handle != (void *)(uintptr_t)123) return 0;
    *code = 259;
    return injected_read;
}
int32_t sollang_probe_close(void *handle) {
    ++close_calls;
    return handle == (void *)(uintptr_t)123 ? injected_close : 0;
}
static int injected_case(int waited, int read, int closed, int expected_state,
                         int expected_reads, int expected_closes, const char *name) {
    wait_calls = read_calls = close_calls = 0;
    injected_wait = waited; injected_read = read; injected_close = closed;
    uint64_t result = sollang_probe_poll_injected(123);
    return check(poll_state(result) == expected_state && wait_calls == 1
        && read_calls == expected_reads && close_calls == expected_closes
        && (expected_state != 1 || poll_code(result) == 259), name, 1);
}

int main(int argc, char **argv) {
    if (argc == 2 && strcmp(argv[1], "--child") == 0) return 259;
    STARTUPINFOA startup = {0};
    PROCESS_INFORMATION child = {0};
    char executable[32768], command[32784];
    int outcome = 1;
    startup.cb = sizeof(startup);
    DWORD length = GetModuleFileNameA(NULL, executable, sizeof(executable));
    if (!length || length >= sizeof(executable)) goto done;
    int written = snprintf(command, sizeof(command), "\"%s\" --child", executable);
    if (written < 0 || (size_t)written >= sizeof(command)) goto done;
    // The suspended initial thread is the barrier, not an elapsed-time guess.
    if (!CreateProcessA(NULL, command, NULL, NULL, FALSE, CREATE_SUSPENDED,
                        NULL, NULL, &startup, &child)) goto done;
    uint64_t token = (uint64_t)(uintptr_t)child.hProcess;
    if (!check(poll_state(sollang_probe_poll(token)) == 0
        && poll_state(sollang_probe_poll(token)) == 0, "suspended-running-twice", 0)) goto done;
    if (ResumeThread(child.hThread) != 1) goto done;
    if (!CloseHandle(child.hThread)) goto done;
    child.hThread = NULL;
    if (WaitForSingleObject(child.hProcess, 5000) != WAIT_OBJECT_0) goto done;
    uint64_t terminal = sollang_probe_poll(token);
    DWORD flags;
    int closed = !GetHandleInformation(child.hProcess, &flags) && GetLastError() == ERROR_INVALID_HANDLE;
    if (closed) child.hProcess = NULL;
    if (!check(poll_state(terminal) == 1 && poll_code(terminal) == 259 && closed,
               "barrier-released-exit-259", 0)) goto done;
    if (!check(poll_state(sollang_probe_poll(0)) == 2, "invalid-token", 0)) goto done;
    if (!injected_case(258, 1, 1, 0, 0, 0, "timeout-does-not-query-or-close")) goto done;
    if (!injected_case(0, 1, 1, 1, 1, 1, "terminal-close-exactly-once")) goto done;
    if (!injected_case(-1, 1, 1, 2, 0, 0, "wait-failure-preserves-owner")) goto done;
    if (!injected_case(0, 0, 1, 2, 1, 0, "query-failure-preserves-owner")) goto done;
    if (!injected_case(0, 1, 0, 2, 1, 1, "close-failure-is-not-success")) goto done;
    outcome = 0;
done:
    if (child.hProcess) {
        if (!TerminateProcess(child.hProcess, 99)
            || WaitForSingleObject(child.hProcess, 5000) != WAIT_OBJECT_0) outcome = 1;
        if (!CloseHandle(child.hProcess)) outcome = 1;
    }
    if (child.hThread && !CloseHandle(child.hThread)) outcome = 1;
    if (!outcome) printf("actual=%d injected=%d outstanding=0\n", actual_checks, injected_checks);
    return outcome;
}

#else
#include <errno.h>
#include <signal.h>
#include <sys/ptrace.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static int injection_mode, wait_calls;
int32_t sollang_probe_waitpid(int32_t pid, int32_t *status, int32_t options) {
    ++wait_calls;
    if (pid != 123 || options != WNOHANG || wait_calls > 2) { errno = EINVAL; return -1; }
    if ((injection_mode == 1 || injection_mode == 2) && wait_calls == 1) {
        errno = EINTR; return -1;
    }
    if (injection_mode == 1) return 0;
    if (injection_mode == 2) { *status = 11 << 8; return pid; }
    if (injection_mode == 3) { errno = ECHILD; return -1; }
    if (injection_mode == 4) { *status = (SIGSTOP << 8) | 127; return pid; }
    *status = SIGTERM;
    return pid;
}
static int injected_case(int mode, int expected_state, int calls, const char *name) {
    injection_mode = mode; wait_calls = 0;
    uint64_t result = sollang_probe_poll_injected(123);
    return check(poll_state(result) == expected_state && wait_calls == calls
        && (mode != 2 || poll_code(result) == 11), name, 1);
}
static int64_t monotonic_millis(void) {
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) return -1;
    return (int64_t)now.tv_sec * 1000 + now.tv_nsec / 1000000;
}
static uint64_t await_terminal(pid_t child) {
    int64_t started = monotonic_millis();
    if (started < 0) return UINT64_C(2) << 32;
    for (;;) {
        uint64_t result = sollang_probe_poll((uint64_t)child);
        if (poll_state(result) != 0) return result;
        int64_t now = monotonic_millis();
        if (now < 0 || now - started >= 5000) return UINT64_C(2) << 32;
        struct timespec backoff = {0, 1000000};
        nanosleep(&backoff, NULL); // Backoff only; state/deadline determine completion.
    }
}
static int observe_stop(pid_t child) {
    int64_t started = monotonic_millis();
    if (started < 0) return 0;
    for (;;) {
        siginfo_t information = {0};
        if (waitid(P_PID, (id_t)child, &information, WSTOPPED | WNOHANG | WNOWAIT) != 0) {
            if (errno == EINTR) continue;
            return 0;
        }
        if (information.si_pid == child) return information.si_code == CLD_TRAPPED;
        int64_t now = monotonic_millis();
        if (now < 0 || now - started >= 5000) return 0;
        struct timespec backoff = {0, 1000000};
        nanosleep(&backoff, NULL);
    }
}
static int cleanup_child(pid_t child) {
    if (child <= 0) return 1;
    if (kill(child, SIGKILL) != 0 && errno != ESRCH) return 0;
    int status;
    pid_t reaped;
    do { reaped = waitpid(child, &status, 0); } while (reaped < 0 && errno == EINTR);
    return reaped == child || (reaped < 0 && errno == ECHILD);
}
static int was_reaped(pid_t *child) {
    int status;
    pid_t result;
    do { result = waitpid(*child, &status, WNOHANG); } while (result < 0 && errno == EINTR);
    int already_reaped = result < 0 && errno == ECHILD;
    if (already_reaped || result == *child) *child = 0;
    return already_reaped;
}

int main(void) {
    pid_t owned_child = 0;
    int barrier[2] = {-1, -1};
    int outcome = 1;
    if (pipe(barrier) != 0) goto done;
    owned_child = fork();
    if (owned_child == 0) {
        close(barrier[1]);
        char release;
        ssize_t count;
        do { count = read(barrier[0], &release, 1); } while (count < 0 && errno == EINTR);
        close(barrier[0]);
        _exit(count == 1 ? 7 : 98);
    }
    if (owned_child < 0) goto done;
    close(barrier[0]); barrier[0] = -1;
    if (!check(poll_state(sollang_probe_poll((uint64_t)owned_child)) == 0
        && poll_state(sollang_probe_poll((uint64_t)owned_child)) == 0, "pipe-barrier-running-twice", 0)) goto done;
    if (write(barrier[1], "x", 1) != 1) goto done;
    close(barrier[1]); barrier[1] = -1;
    pid_t observed_child = owned_child;
    uint64_t terminal = await_terminal(owned_child);
    int reaped = was_reaped(&owned_child);
    if (!check(poll_state(terminal) == 1 && poll_code(terminal) == 7 && reaped, "released-normal-exit", 0)) goto done;
    if (!check(poll_state(sollang_probe_poll((uint64_t)observed_child)) == 2,
               "already-reaped-echild", 0)) goto done;
    if (!check(poll_state(sollang_probe_poll(0)) == 2, "invalid-token", 0)) goto done;

    owned_child = fork();
    if (owned_child == 0) {
        if (ptrace(PTRACE_TRACEME, 0, NULL, NULL) != 0) _exit(97);
        raise(SIGSTOP);
        _exit(9);
    }
    if (owned_child < 0 || !observe_stop(owned_child)) goto done;
    // WNOWAIT left the real traced-stop status for the production poll function.
    if (!check(poll_state(sollang_probe_poll((uint64_t)owned_child)) == 0,
               "real-traced-stop-is-not-terminal", 0)) goto done;
    if (ptrace(PTRACE_CONT, owned_child, NULL, NULL) != 0) goto done;
    terminal = await_terminal(owned_child);
    reaped = was_reaped(&owned_child);
    if (!check(poll_state(terminal) == 1 && poll_code(terminal) == 9 && reaped,
               "traced-child-continues-and-exits", 0)) goto done;

    owned_child = fork();
    if (owned_child == 0) { for (;;) pause(); }
    if (owned_child < 0 || kill(owned_child, SIGTERM) != 0) goto done;
    terminal = await_terminal(owned_child);
    reaped = was_reaped(&owned_child);
    if (!check(poll_state(terminal) == 3 && reaped, "real-signal-terminal", 0)) goto done;

    if (!injected_case(1, 0, 2, "eintr-then-running")) goto done;
    if (!injected_case(2, 1, 2, "eintr-then-exited")) goto done;
    if (!injected_case(3, 2, 1, "echild-is-not-retried")) goto done;
    if (!injected_case(4, 0, 1, "injected-stop-is-not-terminal")) goto done;
    if (!injected_case(5, 3, 1, "injected-signal-is-terminal")) goto done;
    outcome = 0;
done:
    if (barrier[0] >= 0) close(barrier[0]);
    if (barrier[1] >= 0) close(barrier[1]);
    if (!cleanup_child(owned_child)) outcome = 1;
    if (!outcome) printf("actual=%d injected=%d outstanding=0\n", actual_checks, injected_checks);
    return outcome;
}
#endif
