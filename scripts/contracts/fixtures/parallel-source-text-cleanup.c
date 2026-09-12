#include <stdint.h>
#include <stdio.h>
#include <string.h>

extern void sollang_probe_source(void *owner, int64_t length);
extern void sollang_probe_array(void *data);

static int free_calls;
static int windows_unmap_calls;
static int linux_unmap_calls;
static void *observed_owner;
static int64_t observed_length;

// Observe the exact terminal chosen by the production LLVM. No host resource
// is released: the frozen baseline incorrectly frees mapped storage, so sending
// that request to the real allocator would make this regression unsafe.
void sollang_probe_free(void *owner)
{
    ++free_calls;
    observed_owner = owner;
}

int sollang_probe_windows_unmap(void *owner)
{
    ++windows_unmap_calls;
    observed_owner = owner;
    return 1;
}

int sollang_probe_linux_unmap(void *owner, int64_t length)
{
    ++linux_unmap_calls;
    observed_owner = owner;
    observed_length = length;
    return 0;
}

static void reset(void)
{
    free_calls = 0;
    windows_unmap_calls = 0;
    linux_unmap_calls = 0;
    observed_owner = NULL;
    observed_length = 0;
}

static int check(const char *name, int expected_free, int expected_windows,
    int expected_linux, void *owner, int64_t length)
{
    if (free_calls != expected_free || windows_unmap_calls != expected_windows ||
        linux_unmap_calls != expected_linux || observed_owner != owner ||
        (expected_linux != 0 && observed_length != length)) {
        fprintf(stderr, "FAIL %s free=%d windows=%d linux=%d owner=%d length=%lld\n",
            name, free_calls, windows_unmap_calls, linux_unmap_calls,
            observed_owner == owner, (long long)observed_length);
        return 0;
    }
    printf("%s:free=%d,windows=%d,linux=%d\n", name, free_calls,
        windows_unmap_calls, linux_unmap_calls);
    return 1;
}

int main(int argc, char **argv)
{
    if (argc != 3 || (strcmp(argv[1], "baseline") != 0 && strcmp(argv[1], "candidate") != 0) ||
        (strcmp(argv[2], "windows") != 0 && strcmp(argv[2], "linux") != 0)) {
        fprintf(stderr, "usage: cleanup-probe baseline|candidate windows|linux\n");
        return 2;
    }
    const int baseline = strcmp(argv[1], "baseline") == 0;
    const int windows = strcmp(argv[2], "windows") == 0;
    unsigned char heap_marker = 0;
    unsigned char mapped_marker = 0;
    unsigned char array_marker = 0;

    reset();
    sollang_probe_source(NULL, 0);
    if (!check("borrowed", baseline, 0, 0, NULL, 0)) return 1;

    reset();
    sollang_probe_source(&heap_marker, -1);
    if (!check("heap", 1, 0, 0, &heap_marker, 0)) return 1;

    reset();
    sollang_probe_source(&mapped_marker, 4096);
    if (!check("mapped", baseline, !baseline && windows, !baseline && !windows,
        &mapped_marker, 4096)) return 1;

    reset();
    sollang_probe_array(&array_marker);
    if (!check("array", 1, 0, 0, &array_marker, 0)) return 1;

    printf("parallel cleanup %s %s: 4/4\n", argv[1], argv[2]);
    return 0;
}
