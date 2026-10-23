#include <stdint.h>
#include <stdio.h>
#include <stddef.h>
static uint64_t observed;
static uintptr_t next;
static uint32_t mode, bad_pointer;
static unsigned char buffer[1048580];
int32_t probe_WriteFile(void *handle, void *data, uint32_t count, uint32_t *written, void *overlapped) {
    if (observed && (uintptr_t)data != next) bad_pointer = 1;
    if (mode == 2) { *written = 0; return 0; }
    if (mode == 3) { *written = 0; return 1; }
    if (mode == 4) { *written = count + 1; return 1; }
    *written = mode == 1 && count > 65537 ? 65537 : count;
    observed += *written;
    next = (uintptr_t)data + *written;
    return 1;
}
int32_t probe_WriteConsoleW(void *h, void *d, uint32_t n, uint32_t *w, void *r) { return 0; }
int32_t probe_MultiByteToWideChar(uint32_t cp, uint32_t flags, void *data, int32_t n, void *wide, int32_t room) { return 0; }
void *probe_GetProcessHeap(void) { return 0; }
void *probe_HeapAlloc(void *h, uint32_t flags, uint64_t bytes) { return 0; }
int32_t probe_HeapFree(void *h, uint32_t flags, void *data) { return 1; }
void *probe_GetStdHandle(int32_t kind) { return (void *)(uintptr_t)(kind == -12 ? 12 : 11); }
int32_t probe_GetConsoleMode(void *h, void *mode) { return 0; }
extern int32_t exercise_stdout(void *, uint64_t);
extern int32_t exercise_stderr(void *, uint64_t);
extern int32_t exercise_stderr_status(void *, uint64_t);
int main(void) {
    const uint64_t lengths[] = {0, 1, 1048576, 1048577, 2147483648ULL, 4294967296ULL, 4294967297ULL};
    for (mode=0; mode<=1; ++mode) {
        for (unsigned stream=0; stream<2; ++stream) {
            for (unsigned i=0; i<sizeof(lengths)/sizeof(lengths[0]); ++i) {
                observed = 0; next = 0; bad_pointer = 0;
                int32_t ok = stream ? exercise_stderr(buffer, lengths[i]) : exercise_stdout(buffer, lengths[i]);
                printf("%u:%u:%llu:%d:%llu:%u\n", mode, stream, (unsigned long long)lengths[i], ok, (unsigned long long)observed, bad_pointer);
            }
        }
    }
    for (mode=2; mode<=4; ++mode) {
        observed = 0; next = 0; bad_pointer = 0;
        int32_t ok = exercise_stderr_status(buffer, 4096);
        printf("failure%u:%d\n", mode, ok);
    }
    return 0;
}
