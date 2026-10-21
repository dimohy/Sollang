#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/epoll.h>
#include <sys/eventfd.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <unistd.h>

_Static_assert(sizeof(pthread_mutex_t) == 40, "Linux x86_64 mutex ABI");
extern void *sollang_socket_completion_waiter(void *);
extern int32_t socket_probe_receive(void *, void *, int32_t *);
extern int32_t socket_probe_cancel(void *);
extern int32_t socket_probe_dequeue(void *, void *);
extern int32_t socket_probe_create(int64_t *, int32_t *);

static int scenario, peer_fd, saved_epoll = -1, saved_wakeup = -1;
static unsigned wait_calls, signal_calls, unexpected_calls, mod_calls;
static uint64_t *active_state;
static pthread_mutex_t schedule_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t schedule_changed = PTHREAD_COND_INITIALIZER;
static pthread_barrier_t race_start;
static int event_available, event_observed;
static void *allocated[4];
static unsigned allocation_count, free_count;
static int cancel_kind, dequeue_kind;
static uint64_t raced_descriptor[11];

int sollang_platform_io_ensure_signal(void) { ++unexpected_calls; return 0; }
void sollang_io_push_completion(void *task) { (void)task; ++unexpected_calls; }
void sollang_platform_io_signal_completion(void) { ++signal_calls; }

void *socket_probe_alloc(uint64_t bytes) {
    static const uint64_t expected_sizes[] = {144, 32, 128, 32};
    if (allocation_count < 4 && bytes != expected_sizes[allocation_count]) ++unexpected_calls;
    void *p = malloc((size_t)bytes);
    if (allocation_count >= 4 || !p) { ++unexpected_calls; return p; }
    allocated[allocation_count++] = p;
    return p;
}
void socket_probe_free(void *p) {
    for (unsigned i = 0; i < allocation_count; ++i) {
        if (allocated[i] == p) { allocated[i] = NULL; ++free_count; free(p); return; }
    }
    ++unexpected_calls;
}
int socket_probe_mutex_init(pthread_mutex_t *mutex, const pthread_mutexattr_t *attr) {
    return scenario == 3 ? EAGAIN : pthread_mutex_init(mutex, attr);
}

int socket_probe_epoll_ctl(int epoll, int operation, int fd, struct epoll_event *event) {
    if (scenario == 3) { saved_epoll = epoll; saved_wakeup = fd; }
    if (operation == EPOLL_CTL_MOD) {
        ++mod_calls;
        if (scenario == 1 && mod_calls == 2) { errno = EBADF; return -1; }
    }
    int result = epoll_ctl(epoll, operation, fd, event);
    if (result || operation != EPOLL_CTL_MOD || scenario != 0) return result;
    if (mod_calls == 1) {
        /* Deliver readiness before submit has published its pending slot.
           The worker must serialize its table inspection with that publication. */
        uint64_t *pending = (uint64_t *)(uintptr_t)active_state[3];
        if (pending[0] != 0 || active_state[9] != 0) ++unexpected_calls;
        int locked = pthread_mutex_trylock((pthread_mutex_t *)(active_state + 13));
        if (locked != EBUSY) {
            ++unexpected_calls;
            if (!locked) pthread_mutex_unlock((pthread_mutex_t *)(active_state + 13));
        }
        pthread_mutex_lock(&schedule_lock);
        event_available = 1;
        pthread_cond_broadcast(&schedule_changed);
        while (!event_observed) pthread_cond_wait(&schedule_changed, &schedule_lock);
        pthread_mutex_unlock(&schedule_lock);
    } else if (mod_calls == 2) {
        uint64_t *pending = (uint64_t *)(uintptr_t)active_state[3];
        if (pending[0] != 1 || active_state[9] != 1) ++unexpected_calls;
        unsigned char byte = 55;
        if (send(peer_fd, &byte, 1, MSG_NOSIGNAL) != 1) ++unexpected_calls;
    }
    return result;
}

int socket_probe_epoll_wait(int epoll, struct epoll_event *events, int capacity, int timeout) {
    (void)epoll;
    if (capacity != 1 || timeout != -1) ++unexpected_calls;
    ++wait_calls;
    memset(events, 0, sizeof *events);
    if (wait_calls == 1) {
        if (scenario == 0) {
            pthread_mutex_lock(&schedule_lock);
            while (!event_available) pthread_cond_wait(&schedule_changed, &schedule_lock);
            event_observed = 1;
            pthread_cond_broadcast(&schedule_changed);
            pthread_mutex_unlock(&schedule_lock);
        } else if (scenario == 2) {
            pthread_barrier_wait(&race_start);
        }
        events->events = EPOLLIN;
        events->data.u64 = 3;
    } else {
        atomic_store_explicit((_Atomic int32_t *)((char *)active_state + 96), 1, memory_order_release);
        events->events = EPOLLIN;
        events->data.u64 = 0;
    }
    return 1;
}

static void *cancel_thread(void *state) {
    pthread_barrier_wait(&race_start);
    cancel_kind = socket_probe_cancel(state);
    return NULL;
}
static void *dequeue_thread(void *state) {
    pthread_barrier_wait(&race_start);
    dequeue_kind = socket_probe_dequeue(state, raced_descriptor);
    return NULL;
}

static int operation_case(void) {
    int pair[2];
    if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0, pair)) return 10;
    int epoll = epoll_create1(EPOLL_CLOEXEC), wakeup = eventfd(0, EFD_CLOEXEC | EFD_NONBLOCK);
    if (epoll < 0 || wakeup < 0) return 11;
    struct epoll_event event = {.events = EPOLLIN | EPOLLONESHOT, .data.u64 = 3};
    if (epoll_ctl(epoll, EPOLL_CTL_ADD, pair[0], &event)) return 12;
    uint64_t state[18] = {0}, pending[16] = {0}, completion[4] = {0};
    uint64_t registration[4] = {1, 17, (uint64_t)pair[0], 3};
    unsigned char payload = 0;
    state[0] = (uint64_t)epoll; state[1] = (uint64_t)wakeup;
    state[2] = (uintptr_t)registration; state[3] = (uintptr_t)pending;
    state[4] = (uintptr_t)completion;
    state[5] = state[6] = state[7] = state[8] = state[10] = 1;
    active_state = state; peer_fd = pair[1];
    if (pthread_mutex_init((pthread_mutex_t *)(state + 13), NULL)) return 13;
    int ok;
    uint64_t descriptor[11] = {0};
    if (scenario < 2) {
        pthread_t worker;
        if (scenario == 0 && pthread_create(&worker, NULL, sollang_socket_completion_waiter, state)) return 14;
        int32_t code = 0;
        int kind = socket_probe_receive(state, &payload, &code);
        if (scenario == 0 && pthread_join(worker, NULL)) return 15;
        ok = kind == -2 && code == 0 && mod_calls == 2 && pending[0] == 2
            && state[9] == 0 && signal_calls == 1;
        ok = ok && socket_probe_dequeue(state, descriptor) == -1
            && descriptor[0] == 31 && descriptor[2] == (uintptr_t)&payload
            && pending[4] == 0 && pending[0] == 0;
        if (scenario == 0) ok = ok && payload == 55 && descriptor[7] == 1
            && ((int32_t *)descriptor)[18] == 0 && wait_calls == 2;
        else ok = ok && payload == 0 && descriptor[7] == 0
            && ((int32_t *)descriptor)[18] == EBADF && wait_calls == 0;
    } else {
        unsigned char byte = 55;
        if (send(pair[1], &byte, 1, MSG_NOSIGNAL) != 1) return 16;
        pending[0] = 1; pending[1] = 31; pending[4] = (uintptr_t)&payload;
        pending[5] = pending[6] = pending[8] = 1; state[9] = 1;
        pthread_t worker, canceller, dequeuer;
        if (pthread_barrier_init(&race_start, NULL, 3)) return 17;
        if (pthread_create(&worker, NULL, sollang_socket_completion_waiter, state)
            || pthread_create(&canceller, NULL, cancel_thread, state)
            || pthread_create(&dequeuer, NULL, dequeue_thread, state)) return 18;
        if (pthread_join(worker, NULL) || pthread_join(canceller, NULL)
            || pthread_join(dequeuer, NULL)) return 19;
        if (dequeue_kind == -2) dequeue_kind = socket_probe_dequeue(state, raced_descriptor);
        ok = dequeue_kind == -1 && (cancel_kind == -1 || cancel_kind == 1)
            && raced_descriptor[0] == 31 && raced_descriptor[2] == (uintptr_t)&payload
            && raced_descriptor[7] == 1 && ((int32_t *)raced_descriptor)[16] == 2
            && ((int32_t *)raced_descriptor)[18] == 0 && payload == 55
            && pending[0] == 0 && pending[4] == 0 && state[9] == 0
            && signal_calls == 1 && wait_calls == 2;
        if (pthread_barrier_destroy(&race_start)) return 20;
    }
    ok = ok && socket_probe_dequeue(state, descriptor) == 1 && !unexpected_calls;
    if (pthread_mutex_destroy((pthread_mutex_t *)(state + 13))) return 21;
    close(pair[0]); close(pair[1]); close(epoll); close(wakeup);
    return ok ? 0 : 22;
}

static int child_case(int index) {
    scenario = index; alarm(4);
    if (scenario == 3) {
        int64_t identity = 0; int32_t code = 0;
        int kind = socket_probe_create(&identity, &code);
        int epoll_closed = saved_epoll >= 0 && fcntl(saved_epoll, F_GETFD) == -1 && errno == EBADF;
        int wakeup_closed = saved_wakeup >= 0 && fcntl(saved_wakeup, F_GETFD) == -1 && errno == EBADF;
        return kind == 8 && code == EAGAIN && identity == -1
            && allocation_count == 4 && free_count == 4 && epoll_closed && wakeup_closed
            && !unexpected_calls ? 0 : 23;
    }
    unsigned rounds = scenario == 2 ? 32 : 1;
    for (unsigned i = 0; i < rounds; ++i) {
        wait_calls = signal_calls = unexpected_calls = mod_calls = 0;
        cancel_kind = dequeue_kind = 99;
        memset(raced_descriptor, 0, sizeof raced_descriptor);
        int result = operation_case();
        if (result) return result;
    }
    return 0;
}

int main(void) {
    const char *names[] = {"readiness-before-publication", "post-publication-rearm-error",
                           "cancel-completion-dequeue-race", "mutex-init-failure-cleanup"};
    int failed = 0;
    for (int index = 0; index < 4; ++index) {
        fflush(NULL);
        pid_t child = fork();
        if (child < 0) return 30;
        if (!child) _exit(child_case(index));
        int status;
        if (waitpid(child, &status, 0) != child) return 31;
        int exited = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
        int signalled = WIFSIGNALED(status) ? WTERMSIG(status) : 0;
        printf("%s: exit=%d signal=%d\n", names[index], exited, signalled);
        if (exited || signalled) ++failed;
    }
    return failed ? 1 : 0;
}
