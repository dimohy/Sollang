#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { LIMIT = 1048576 };
static unsigned char input[LIMIT + 16];
static uint64_t digest, units;
static unsigned mode, allocations, releases, conversions;
static const uint64_t seed = 1469598103934665603ULL;
static const uint64_t prime = 1099511628211ULL;

int32_t probe_WriteFile(void *h, void *d, uint32_t n, uint32_t *w, void *o) { return 0; }
int32_t probe_WriteConsoleW(void *h, void *data, uint32_t count, uint32_t *written, void *reserved) {
    if (mode == 2) { *written = 0; return 1; }
    if (mode == 3) { *written = count + 1; return 1; }
    if (mode == 4) { *written = 0; return 0; }
    *written = mode == 1 && count > 65537 ? 65537 : count;
    const uint16_t *wide = data;
    for (uint32_t i = 0; i < *written; ++i) digest = (digest ^ wide[i]) * prime;
    units += *written;
    return 1;
}
int32_t probe_MultiByteToWideChar(uint32_t cp, uint32_t flags, void *data, int32_t length, void *wide, int32_t room) {
    ++conversions;
    if (mode == 6 && wide) return 0;
    return MultiByteToWideChar(cp, flags, data, length, wide, room);
}
void *probe_GetProcessHeap(void) { return GetProcessHeap(); }
void *probe_HeapAlloc(void *heap, uint32_t flags, uint64_t bytes) {
    if (mode == 5) return NULL;
    void *value = HeapAlloc(heap, flags, (SIZE_T)bytes);
    if (value) ++allocations;
    return value;
}
int32_t probe_HeapFree(void *heap, uint32_t flags, void *data) {
    if (data) ++releases;
    return HeapFree(heap, flags, data);
}
void *probe_GetStdHandle(int32_t kind) { return (void *)(uintptr_t)(kind == -12 ? 12 : 11); }
int32_t probe_GetConsoleMode(void *handle, void *value) { return 1; }
extern int32_t exercise_console(void *, uint64_t);

static size_t prepare(unsigned kind) {
    memset(input, 'a', sizeof(input));
    if (kind == 0) return 0;
    if (kind == 1) return LIMIT + 8;
    if (kind == 8) {
        memset(input + LIMIT - 3, 0x80, 5);
        return LIMIT + 8;
    }
    if (kind == 9) { input[LIMIT + 4] = 0xff; return LIMIT + 8; }
    unsigned back = kind == 7 ? 0 : (kind <= 3 ? kind - 1 : kind - 3);
    const unsigned char three[] = {0xea, 0xb0, 0x80};
    const unsigned char four[] = {0xf0, 0x9f, 0x99, 0x82};
    memcpy(input + LIMIT - back, kind <= 3 || kind == 7 ? three : four, kind <= 3 || kind == 7 ? 3 : 4);
    return LIMIT + 8;
}

static void observe(unsigned kind, unsigned selected_mode) {
    size_t length = prepare(kind);
    int expected_units = length ? MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, (const char *)input, (int)length, NULL, 0) : 0;
    uint64_t expected_digest = seed;
    if (expected_units) {
        uint16_t *whole = malloc((size_t)expected_units * 2);
        if (!whole || MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, (const char *)input, (int)length, (wchar_t *)whole, expected_units) != expected_units) exit(2);
        for (int i = 0; i < expected_units; ++i) expected_digest = (expected_digest ^ whole[i]) * prime;
        free(whole);
    }
    mode = selected_mode; allocations = releases = conversions = 0; units = 0; digest = seed;
    int ok = exercise_console(input, length);
    int valid = kind < 8 && mode < 2;
    int matches = valid ? ok == 1 && units == (uint64_t)expected_units && digest == expected_digest : ok == 0;
    printf("%u:%u:%d:%d:%d\n", kind, mode, ok, matches, allocations == releases);
}

int main(void) {
    for (unsigned selected_mode = 0; selected_mode < 2; ++selected_mode)
        for (unsigned kind = 0; kind < 8; ++kind) observe(kind, selected_mode);
    observe(8, 0); observe(9, 0);
    for (unsigned selected_mode = 2; selected_mode <= 6; ++selected_mode) observe(1, selected_mode);
    return 0;
}
