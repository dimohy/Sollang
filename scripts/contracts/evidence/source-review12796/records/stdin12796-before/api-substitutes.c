#include <stdint.h>
#include <stdio.h>
static uint32_t observed, mode;
int32_t ReadFile(void *h, void *data, uint32_t count, uint32_t *read, void *overlapped) {
    observed = count;
    if (mode) return 0;
    *read = count > 7 ? 7 : count;
    return 1;
}
uint32_t GetLastError(void) { return mode == 1 ? 109 : 5; }
void *GetStdHandle(int32_t kind) { return 0; }
extern int64_t exercise(uint64_t capacity);
int main(void) {
    const uint64_t capacities[] = {0, 1, 4096, 2147483648ULL, 4294967295ULL, 4294967296ULL, UINT64_MAX};
    for (unsigned i=0; i<sizeof(capacities)/sizeof(capacities[0]); ++i) {
        int64_t result = exercise(capacities[i]);
        printf("%llu:%u:%lld\n", (unsigned long long)capacities[i], observed, (long long)result);
    }
    for (mode=1; mode<=2; ++mode) {
        int64_t result = exercise(4096);
        printf("error%u:%lld\n", mode, (long long)result);
    }
    return 0;
}
