#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static unsigned mode, calls, allocation_calls, allocations, releases, bad_key;
static uint32_t error_code;
static const WCHAR value[] = {0xac12, 0xd83d, 0xde42, 0};
static const unsigned char expected[] = {0xea, 0xb0, 0x92, 0xf0, 0x9f, 0x99, 0x82};

void *probe_alloc(uint64_t bytes) {
    ++allocation_calls;
    if ((mode == 12 && allocation_calls == 1) || (mode == 13 && allocation_calls == 4) ||
        (mode == 14 && allocation_calls == 2) || (mode == 15 && allocation_calls == 3)) return NULL;
    void *p = malloc((size_t)bytes);
    if (p) ++allocations;
    return p;
}
void probe_free(void *data) {
    if (data) ++releases;
    free(data);
    /* Cleanup must not replace the error captured immediately after the API. */
    error_code = 31;
}
void probe_SetLastError(uint32_t code) { error_code = code; }
uint32_t probe_GetLastError(void) { return error_code; }
int32_t probe_MultiByteToWideChar(uint32_t cp, uint32_t flags, void *data, int32_t length, void *wide, int32_t room) {
    return MultiByteToWideChar(cp, flags, data, length, wide, room);
}
int32_t probe_WideCharToMultiByte(uint32_t cp, uint32_t flags, void *wide, int32_t length, void *data, int32_t room, void *fallback, void *used) {
    if (mode == 16 && data) return 0;
    return WideCharToMultiByte(cp, flags, wide, length, data, room, fallback, used);
}
uint32_t probe_GetEnvironmentVariableW(const WCHAR *name, WCHAR *data, uint32_t room) {
    ++calls;
    if (!name || name[0] != 'k' || name[1] != 'e' || name[2] != 'y' || name[3] != 0) bad_key = 1;
    if (!data) {
        if (mode == 1) { error_code = 203; return 0; }
        if (mode == 2) { error_code = 0; return 0; }
        if (mode == 3) { error_code = 87; return 0; }
        if (mode == 4) { error_code = 5; return 0; }
        error_code = mode == 7 ? 123 : 0;
        return 4;
    }
    if (mode == 5) { error_code = 203; return 0; }
    if (mode == 6) { error_code = 87; return 0; }
    if (mode == 7) return 0;
    if (mode == 8) return 8;
    if (room < 4) return 4;
    memcpy(data, value, sizeof(value));
    return 3;
}

extern void observe_lookup(void *, uint64_t, void **, uint64_t *, uint8_t *, uint8_t *);
extern int32_t observe_entry(uint64_t);
extern void dispose_lookup(void);
int main(void) {
    unsigned char key[] = {'k', 'e', 'y'};
    unsigned char invalid[] = {0xff};
    unsigned char embedded[] = {'k', 0, 'y'};
    for (mode = 0; mode <= 16; ++mode) {
        calls = allocation_calls = allocations = releases = bad_key = 0;
        error_code = 999;
        void *data = NULL;
        uint64_t length = 0;
        uint8_t present = 0, ok = 0;
        void *name = mode == 9 ? invalid : mode == 10 ? embedded : key;
        uint64_t name_length = mode == 11 ? 0 : mode == 9 ? 1 : 3;
        observe_lookup(name, name_length, &data, &length, &present, &ok);
        int matches = !bad_key && (length == 0 || (length == sizeof(expected) && data && memcmp(data, expected, sizeof(expected)) == 0));
        dispose_lookup();
        printf("body:%u:%u:%u:%llu:%d:%d:%u\n", mode, present, ok, (unsigned long long)length, matches, allocations == releases, calls);
    }
    const uint64_t lengths[] = {0, 1, 2147483647ULL, 2147483648ULL, 4294967296ULL, 4294967299ULL, UINT64_MAX};
    for (unsigned i = 0; i < sizeof(lengths) / sizeof(lengths[0]); ++i)
        printf("entry:%llu:%d\n", (unsigned long long)lengths[i], observe_entry(lengths[i]));
    return 0;
}
