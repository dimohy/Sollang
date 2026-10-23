#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

enum { THREADS = 8, PER_THREAD = 1024, TOTAL = THREADS * PER_THREAD };
static HANDLE start_event;
static uint64_t payloads[TOTAL];
static void *nodes[TOTAL];
static unsigned char seen[TOTAL], released_nodes[TOTAL], released_payloads[TOTAL];
static volatile LONG allocated, accepted;
static unsigned errors, node_frees, payload_frees;
extern unsigned char observe_track(void *);
extern void *observe_head(void);
extern void observe_dispose(void);

void *probe_alloc(uint64_t size) {
    void *node = malloc((size_t)size);
    if (node) {
        LONG slot = InterlockedIncrement(&allocated) - 1;
        if (slot >= TOTAL) abort();
        nodes[slot] = node;
    }
    return node;
}

/* Record release ownership, retaining storage until the observation completes.
   This allows duplicate/corrupt ownership to fail without dereferencing freed memory. */
void probe_free(void *pointer) {
    for (unsigned i = 0; i < TOTAL; ++i) {
        if (pointer == &payloads[i]) {
            errors += released_payloads[i]++ != 0;
            ++payload_frees;
            return;
        }
        if (pointer == nodes[i]) {
            errors += released_nodes[i]++ != 0;
            ++node_frees;
            return;
        }
    }
    ++errors;
}

static DWORD WINAPI worker(void *argument) {
    unsigned first = (unsigned)(uintptr_t)argument * PER_THREAD;
    if (WaitForSingleObject(start_event, 10000) != WAIT_OBJECT_0) return 1;
    for (unsigned i = first; i < first + PER_THREAD; ++i)
        if (observe_track(&payloads[i])) InterlockedIncrement(&accepted);
    return 0;
}

int main(void) {
    HANDLE threads[THREADS];
    start_event = CreateEventW(NULL, TRUE, FALSE, NULL);
    if (!start_event) return 2;
    for (unsigned i = 0; i < THREADS; ++i) {
        threads[i] = CreateThread(NULL, 0, worker, (void *)(uintptr_t)i, 0, NULL);
        if (!threads[i]) return 3;
    }
    if (!SetEvent(start_event)) return 4;
    if (WaitForMultipleObjects(THREADS, threads, TRUE, 15000) != WAIT_OBJECT_0) return 5;
    for (unsigned i = 0; i < THREADS; ++i) {
        DWORD status;
        if (!GetExitCodeThread(threads[i], &status) || status) return 6;
        CloseHandle(threads[i]);
    }
    CloseHandle(start_event);
    unsigned retained = 0;
    for (void **node = observe_head(); node; node = node[1]) {
        if (++retained > TOTAL) return 7;
        uintptr_t pointer = (uintptr_t)node[0], base = (uintptr_t)payloads;
        if (pointer < base || pointer >= base + sizeof(payloads) ||
            (pointer - base) % sizeof(payloads[0])) return 8;
        unsigned index = (unsigned)((pointer - base) / sizeof(payloads[0]));
        errors += seen[index]++ != 0;
    }
    observe_dispose();
    printf("accepted=%ld retained=%u nodes=%u payloads=%u errors=%u\n",
        accepted, retained, node_frees, payload_frees, errors);
    for (LONG i = 0; i < allocated; ++i) free(nodes[i]);
    return accepted == TOTAL && retained == TOTAL && node_frees == TOTAL &&
        payload_frees == TOTAL && errors == 0 ? 0 : 1;
}
