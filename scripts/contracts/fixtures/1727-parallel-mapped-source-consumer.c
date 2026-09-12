#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>

extern int sollang_start(void);

static volatile LONG maps;
static volatile LONG unmaps;
static volatile LONG failed_maps;
static volatile LONG failed_unmaps;

// These observers delegate to the real OS APIs. The generated program's
// ownership, scheduling, callback, payload and cleanup control flow is intact.
void *sollang_probe_MapViewOfFile(void *mapping, uint32_t access,
    uint32_t high, uint32_t low, uint64_t length)
{
    void *view = MapViewOfFile(mapping, access, high, low, (SIZE_T)length);
    InterlockedIncrement(view != NULL ? &maps : &failed_maps);
    return view;
}

int sollang_probe_UnmapViewOfFile(void *view)
{
    const int result = UnmapViewOfFile(view);
    InterlockedIncrement(result ? &unmaps : &failed_unmaps);
    return result;
}

int main(void)
{
    const int result = sollang_start();
    if (result != 0 || maps != 2 || unmaps != 2 || failed_maps != 0 || failed_unmaps != 0) {
        fprintf(stderr, "FAIL consumer exit=%d map=%ld unmap=%ld failed-map=%ld failed-unmap=%ld\n",
            result, maps, unmaps, failed_maps, failed_unmaps);
        return 1;
    }
    printf("real-os:map=%ld,unmap=%ld,failures=0\n", maps, unmaps);
    return 0;
}
