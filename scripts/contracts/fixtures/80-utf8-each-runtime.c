#include <stdint.h>
#include <stdio.h>

extern uint64_t sollang_probe_decode(const unsigned char *, uint64_t, uint64_t);
extern uint64_t sollang_probe_each(const unsigned char *, uint64_t, uint32_t *);

typedef struct {
    unsigned char bytes[4];
    uint64_t length;
    uint32_t scalar;
} Valid;

static const Valid valid[] = {
    {{0x00}, 1, 0}, {{0x7f}, 1, 0x7f},
    {{0xc2, 0x80}, 2, 0x80}, {{0xdf, 0xbf}, 2, 0x7ff},
    {{0xe0, 0xa0, 0x80}, 3, 0x800}, {{0xed, 0x9f, 0xbf}, 3, 0xd7ff},
    {{0xee, 0x80, 0x80}, 3, 0xe000}, {{0xef, 0xbf, 0xbf}, 3, 0xffff},
    {{0xf0, 0x90, 0x80, 0x80}, 4, 0x10000},
    {{0xf4, 0x8f, 0xbf, 0xbf}, 4, 0x10ffff}
};
static const Valid invalid[] = {
    {{0x80}, 1, 0}, {{0xbf}, 1, 0}, {{0xff}, 1, 0},
    {{0xc0, 0x80}, 2, 0}, {{0xc1, 0xbf}, 2, 0},
    {{0xc2}, 1, 0}, {{0xc2, 0x41}, 2, 0},
    {{0xe0, 0x80, 0x80}, 3, 0}, {{0xe0, 0xa0}, 2, 0},
    {{0xed, 0xa0, 0x80}, 3, 0}, {{0xed, 0xbf, 0xbf}, 3, 0},
    {{0xf0, 0x80, 0x80, 0x80}, 4, 0},
    {{0xf4, 0x90, 0x80, 0x80}, 4, 0},
    {{0xf5, 0x80, 0x80, 0x80}, 4, 0},
    {{0xf0, 0x90, 0x80}, 3, 0}, {{0xf0, 0x90, 0x80, 0x41}, 4, 0}
};

int main(void)
{
    for (unsigned i = 0; i < sizeof valid / sizeof valid[0]; ++i) {
        uint64_t actual = sollang_probe_decode(valid[i].bytes, valid[i].length, 0);
        uint64_t expected = (valid[i].length << 32) | valid[i].scalar;
        if (actual != expected) { fprintf(stderr, "FAIL valid %u\n", i); return 1; }
    }
    for (unsigned i = 0; i < sizeof invalid / sizeof invalid[0]; ++i) {
        if (sollang_probe_decode(invalid[i].bytes, invalid[i].length, 0) != UINT64_MAX) {
            fprintf(stderr, "FAIL invalid %u\n", i); return 1;
        }
    }
    if (sollang_probe_decode(NULL, 0, 0) != UINT64_MAX
        || sollang_probe_decode(NULL, 0, UINT64_MAX) != UINT64_MAX) return 1;
    const unsigned char sample[] = {0x41, 0xed, 0x95, 0x9c, 0x65, 0xcc, 0x81, 0xf0, 0x9f, 0x90, 0xb6};
    const uint32_t expected[] = {65, 54620, 101, 769, 128054};
    uint32_t output[sizeof sample] = {0};
    if (sollang_probe_each(sample, sizeof sample, output) != 5) return 1;
    for (unsigned i = 0; i < 5; ++i) {
        if (output[i] != expected[i]) { fprintf(stderr, "FAIL each %u\n", i); return 1; }
    }
    if (sollang_probe_each(NULL, 0, output) != 0) return 1;
    puts("utf8 decoder 28/28; each fragments 2/2");
    return 0;
}
