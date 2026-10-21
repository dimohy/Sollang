#define SOLLANG_SOCKET_COMPLETION_HELPERS_ONLY
#include "linux-completion-sigpipe.c"

static int later_operation_case(int same_registration) {
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
    uint64_t state[13] = {0}, pending[32] = {0};
    struct epoll_event completion = {0};
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
    pending[2] = same_registration ? 0 : 1;
    pending[18] = 0;
    ((int32_t *)pending)[6] = 0;
    ((int32_t *)(pending + 16))[6] = 1;
    pending[4] = (uintptr_t)&input;
    pending[20] = (uintptr_t)&output;
    pending[5] = pending[6] = pending[8] = 1;
    pending[21] = pending[22] = pending[24] = 1;
    sollang_socket_completion_waiter(state);
    unsigned char received = 0;
    int64_t bytes = recv(first[1], &received, 1, MSG_DONTWAIT);
    int ok = pending[0] == 1 && pending[16] == 2
        && ((int32_t *)(pending + 16))[19] == 0 && pending[26] == 1
        && state[9] == 1 && signal_calls == 1 && wait_calls == 2
        && bytes == 1 && received == 42 && !unexpected_calls;
    close(epoll);
    close(first[0]); close(first[1]); close(second[0]); close(second[1]);
    return ok ? 0 : 14;
}

int main(void) {
    const char *names[] = {"distinct-registration", "same-registration"};
    int failed = 0;
    for (int index = 0; index < 2; ++index) {
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
