#define _GNU_SOURCE

#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdatomic.h>
#include <stddef.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <unistd.h>

typedef ssize_t (*recv_fn)(int, void *, size_t, int);

static _Atomic int recv_calls = 0;

ssize_t recv(int socket, void *buffer, size_t length, int flags)
{
    recv_fn next_recv = (recv_fn)dlsym(RTLD_NEXT, "recv");
    int call = atomic_fetch_add_explicit(&recv_calls, 1, memory_order_relaxed) + 1;
    const char *enabled = getenv("SOLLANG_L04_FORCE_EAGAIN");
    if (enabled != NULL && enabled[0] == '1' && call == 2) {
        const char *trace = getenv("SOLLANG_L04_TRACE");
        if (trace != NULL) {
            int descriptor = open(trace, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
            if (descriptor >= 0) {
                static const char marker[] = "forced-recv-call=2\n";
                ssize_t written = write(descriptor, marker, sizeof(marker) - 1);
                int closed = close(descriptor);
                (void)written;
                (void)closed;
            }
        }
        errno = EAGAIN;
        return -1;
    }
    return next_recv(socket, buffer, length, flags);
}
