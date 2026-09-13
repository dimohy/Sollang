#include <stdint.h>

#ifndef AUDIT_XORSHIFT_SEED
#error Define AUDIT_XORSHIFT_SEED for the deterministic P1206 audit.
#endif

static uint64_t state = (uint64_t)AUDIT_XORSHIFT_SEED;

int audit_BCryptGenRandom(void *algorithm, unsigned char *target,
                          int32_t length, int32_t flags) {
    (void)algorithm;
    (void)flags;
    for (int32_t index = 0; index < length; ++index) {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        target[index] = (unsigned char)state;
    }
    return 0;
}
