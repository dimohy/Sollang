#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
typedef struct { void *ptr; size_t size; void *allocator; int live; } Entry;
static Entry entries[65536];
static size_t cursor;
void *sollang_alloc(uint64_t bytes) {
    void *value = HeapAlloc(GetProcessHeap(), 0, (SIZE_T)bytes);
    size_t slot = cursor++ % 65536;
    if (entries[slot].live) { fputs("audit-capacity-exhausted\n", stderr); exit(91); }
    entries[slot] = (Entry){value, (size_t)bytes, __builtin_return_address(0), value != NULL};
    return value;
}
void sollang_free(void *value) {
    if (!value) return;
    Entry *found = NULL;
    for (size_t n = cursor; n > 0 && cursor - n < 65536; --n) {
        Entry *entry = &entries[(n - 1) % 65536];
        if (entry->ptr == value) { found = entry; break; }
    }
    if ((found && !found->live) || !HeapValidate(GetProcessHeap(), 0, value)) {
        uintptr_t base = (uintptr_t)GetModuleHandleW(NULL);
        fprintf(stderr, "invalid-free ptr=%p tracked=%d live=%d bytes=%zu allocRva=%llx freeRva=%llx\n", value, found != NULL, found ? found->live : -1, found ? found->size : 0,
            (unsigned long long)(found ? (uintptr_t)found->allocator - base : 0),
            (unsigned long long)((uintptr_t)__builtin_return_address(0) - base));
        fflush(stderr); exit(90);
    }
    if (found) found->live = 0;
    HeapFree(GetProcessHeap(), 0, value);
}
