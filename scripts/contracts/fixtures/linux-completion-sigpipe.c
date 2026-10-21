#include <errno.h>
#include <signal.h>
#include <pthread.h>

_Static_assert(sizeof(pthread_mutex_t) == 40, "Linux x86_64 mutex ABI");
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/epoll.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <unistd.h>

extern int32_t socket_probe_send(int64_t fd, int32_t *code);
extern int32_t socket_probe_submit(void *state, int32_t *code);
extern void *sollang_socket_completion_waiter(void *state);
static unsigned wait_calls, signal_calls, unexpected_calls;
static uint32_t first_event_flags = EPOLLOUT;
static uint64_t *active_state;

/* Deterministic readiness only; the production send calls the Linux kernel. */
int socket_probe_epoll_wait(int epoll, struct epoll_event *events,
                           int capacity, int timeout) {
    (void)epoll;
    if (capacity != 1 || timeout != -1) ++unexpected_calls;
    memset(events, 0, sizeof *events);
    ++wait_calls;
    /* Keep the tested event's state live; stop only at the next observation. */
    if (wait_calls > 1 && active_state) ((int32_t *)active_state)[24] = 1;
    events->events = wait_calls == 1 ? first_event_flags : EPOLLIN;
    events->data.u64 = wait_calls == 1 ? 3 : 0;
    return 1;
}
int sollang_platform_io_ensure_signal(void) {
    ++unexpected_calls;
    return 0;
}
void sollang_io_push_completion(void *task) {
    (void)task;
    ++unexpected_calls;
}
void sollang_platform_io_signal_completion(void) { ++signal_calls; }

#ifndef SOLLANG_SOCKET_COMPLETION_HELPERS_ONLY
static int child_case(int which) {
    signal(SIGPIPE, SIG_DFL);
    alarm(2);
    int pair[2];
    if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0, pair)) return 10;
    close(pair[1]);
    if (which == 3) first_event_flags = EPOLLERR;
    if (which == 4 || which == 5) first_event_flags = EPOLLHUP;
    int32_t code = 0;
    if (which == 0) {
        int32_t kind = socket_probe_send(pair[0], &code);
        close(pair[0]);
        return kind == 8 && code == EPIPE ? 0 : 11;
    }
    uint64_t state[18] = {0};
    uint64_t registration[4] = {1, 17, (uint64_t)pair[0], 3};
    uint64_t pending[16] = {0};
    uint64_t completion[4] = {0};
    unsigned char payload = 42;
    int epoll = epoll_create1(EPOLL_CLOEXEC);
    if (epoll < 0) return 12;
    struct epoll_event event = {.events = EPOLLOUT | EPOLLONESHOT};
    event.data.u64 = 3;
    if (epoll_ctl(epoll, EPOLL_CTL_ADD, pair[0], &event)) return 13;
    state[0] = (uint64_t)epoll;
    state[2] = (uintptr_t)registration;
    state[3] = (uintptr_t)pending;
    state[4] = (uintptr_t)&completion;
    state[5] = state[6] = state[7] = state[8] = 1;
    state[10] = 1; /* Pre-existing waiter excludes thread creation. */
    if (pthread_mutex_init((pthread_mutex_t *)(state + 13), NULL)) return 15;
    int ok;
    if (which == 1) {
        int32_t kind = socket_probe_submit(state, &code);
        ok = kind == 8 && code == EPIPE && pending[0] == 0 && state[9] == 0;
    } else {
        pending[0] = 1;
        pending[1] = 31;
        pending[2] = 0;
        ((int32_t *)pending)[6] = which == 5 ? 0 : 1;
        pending[4] = (uintptr_t)&payload;
        pending[5] = pending[6] = pending[8] = 1;
        state[9] = 1;
        active_state = state;
        sollang_socket_completion_waiter(state);
        int expected_error = which == 5 ? 0 : EPIPE;
        ok = pending[0] == 2 && ((int32_t *)pending)[19] == expected_error
            && pending[10] == 0 && state[9] == 0
            && signal_calls == 1 && wait_calls == 2;
    }
    if (pthread_mutex_destroy((pthread_mutex_t *)(state + 13))) return 16;
    close(epoll);
    close(pair[0]);
    return ok && !unexpected_calls ? 0 : 14;
}

int main(int argc, char **argv) {
    int baseline = argc == 2 && strcmp(argv[1], "baseline-failure") == 0;
    int readiness = argc == 3 && strcmp(argv[2], "readiness") == 0;
    if (argc >= 2 && strcmp(argv[1], "baseline-failure") == 0) baseline = 1;
    const char *names[] = {"ordinary", "submit", "waiter", "waiter-error",
                           "waiter-hangup", "receiver-hangup"};
    int failed = 0;
    int start = readiness ? 2 : 0, end = readiness ? 6 : 3;
    for (int index = start; index < end; ++index) {
        fflush(NULL);
        pid_t child = fork();
        if (child < 0) return 20;
        if (child == 0) _exit(child_case(index));
        int status;
        if (waitpid(child, &status, 0) != child) return 21;
        int signalled = WIFSIGNALED(status) ? WTERMSIG(status) : 0;
        int exited = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
        printf("%s: exit=%d signal=%d\n", names[index], exited, signalled);
        int expect_signal = baseline && index != 0;
        if (expect_signal ? signalled != SIGPIPE : exited != 0 || signalled)
            ++failed;
    }
    return failed ? 1 : 0;
}
#endif
