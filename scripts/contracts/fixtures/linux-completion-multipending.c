#define SOLLANG_SOCKET_COMPLETION_HELPERS_ONLY
#include "linux-completion-sigpipe.c"

static int later_operation_case(int scenario) {
    signal(SIGPIPE, SIG_DFL);
    alarm(2);
    int first[2], second[2];
    if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0, first)
        || socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0, second)) return 10;
    int epoll = epoll_create1(EPOLL_CLOEXEC);
    if (epoll < 0) return 11;
    struct epoll_event event = {.events = EPOLLIN | EPOLLOUT | EPOLLONESHOT};
    event.data.u64 = 3;
    if (epoll_ctl(epoll, EPOLL_CTL_ADD, first[0], &event)) return 12;
    event.data.u64 = 5;
    if (epoll_ctl(epoll, EPOLL_CTL_ADD, second[0], &event)) return 13;
    uint64_t registrations[8] = {1, 17, (uint64_t)first[0], 3,
                                 1, 18, (uint64_t)second[0], 5};
    uint64_t state[18] = {0}, pending[32] = {0};
    uint64_t completion[4] = {0};
    unsigned char input = 0, output = 42;
    state[0] = (uint64_t)epoll;
    state[2] = (uintptr_t)registrations;
    state[3] = (uintptr_t)pending;
    state[4] = (uintptr_t)&completion;
    state[5] = state[6] = state[8] = state[9] = 2;
    state[7] = state[10] = 1;
    active_state = state;
    pending[0] = pending[16] = 1;
    pending[1] = 31; pending[17] = 32;
    pending[2] = scenario ? 0 : 1;
    pending[18] = 0;
    ((int32_t *)pending)[6] = 0;
    ((int32_t *)(pending + 16))[6] = 1;
    pending[4] = (uintptr_t)&input;
    pending[20] = (uintptr_t)&output;
    pending[5] = pending[6] = pending[8] = 1;
    pending[21] = pending[22] = pending[24] = 1;
    if (pthread_mutex_init((pthread_mutex_t *)(state + 13), NULL)) return 15;
    unsigned char inbound[2] = {71, 72};
    if (scenario >= 2 && scenario <= 5) first_event_flags = EPOLLIN | EPOLLOUT;
    if (scenario == 3 || scenario == 4) {
        ((int32_t *)(pending + 16))[6] = 0;
        pending[20] = (uintptr_t)&output;
    }
    if (scenario == 3 || scenario == 4 || scenario == 5) {
        size_t count = scenario == 3 ? 2 : 1;
        if (send(first[1], inbound, count, MSG_NOSIGNAL) != (ssize_t)count) return 16;
    }
    if (scenario == 6) close(epoll); /* Deterministic MOD failure after send. */
    sollang_socket_completion_waiter(state);
    unsigned char received = 0;
    int64_t bytes = recv(first[1], &received, 1, MSG_DONTWAIT);
    int ok = pending[0] == 1 && pending[16] == 2
        && ((int32_t *)(pending + 16))[19] == 0 && pending[26] == 1
        && state[9] == 1 && signal_calls == 1 && wait_calls == 2
        && bytes == 1 && received == 42 && !unexpected_calls;
    if (scenario == 2) {
        /* First ready receive returns EAGAIN; later send must still complete. */
        ok = ok && input == 0;
    } else if (scenario == 3 || scenario == 5) {
        ok = pending[0] == 2 && pending[16] == 2
            && ((int32_t *)pending)[19] == 0
            && ((int32_t *)(pending + 16))[19] == 0
            && pending[10] == 1 && pending[26] == 1 && input == 71
            && state[9] == 0 && signal_calls == 2 && wait_calls == 2
            && !unexpected_calls;
        if (scenario == 3) ok = ok && output == 72 && bytes == -1 && errno == EAGAIN;
        else ok = ok && bytes == 1 && received == 42;
    } else if (scenario == 4) {
        ok = pending[0] == 2 && pending[16] == 1 && pending[10] == 1
            && input == 71 && output == 42 && state[9] == 1
            && signal_calls == 1 && wait_calls == 2 && !unexpected_calls;
    } else if (scenario == 6) {
        ok = pending[0] == 2 && ((int32_t *)pending)[19] == EBADF
            && pending[10] == 0 && pending[16] == 2 && pending[26] == 1
            && state[9] == 0 && signal_calls == 2 && wait_calls == 2
            && bytes == 1 && received == 42 && !unexpected_calls;
    }
    if (pthread_mutex_destroy((pthread_mutex_t *)(state + 13))) return 17;
    if (scenario != 6) close(epoll);
    close(first[0]); close(first[1]); close(second[0]); close(second[1]);
    return ok ? 0 : 14;
}

int main(void) {
    const char *names[] = {"distinct-registration", "same-registration",
                           "eagain-before-ready", "two-receives",
                           "receive-short-availability", "mixed-both-ready",
                           "rearm-error-completion"};
    int failed = 0;
    for (int index = 0; index < 7; ++index) {
        fflush(NULL);
        pid_t child = fork();
        if (child < 0) return 20;
        if (!child) _exit(later_operation_case(index));
        int status;
        if (waitpid(child, &status, 0) != child) return 21;
        int exited = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
        int signalled = WIFSIGNALED(status) ? WTERMSIG(status) : 0;
        printf("%s: exit=%d signal=%d\n", names[index], exited, signalled);
        if (exited || signalled) ++failed;
    }
    return failed ? 1 : 0;
}
