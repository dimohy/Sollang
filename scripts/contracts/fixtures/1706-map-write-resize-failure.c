#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <string.h>

/* Only the two resize effects are intercepted. File opening, byte storage,
   mapping, and cleanup exercise the actual Windows APIs on our own temp file. */
static int failure_mode;
static int seek_calls;
static int end_calls;
static const unsigned char original[] = { 11, 22, 33, 44, 55, 66, 77, 88 };

extern int sollang_probe_map(const char *path, unsigned long long length,
                             unsigned long long size);

BOOL sollang_probe_seek(HANDLE file, LARGE_INTEGER distance,
                       PLARGE_INTEGER position, DWORD origin)
{
    ++seek_calls;
    if (failure_mode == 1) {
        SetLastError(ERROR_SEEK);
        return FALSE;
    }
    return SetFilePointerEx(file, distance, position, origin);
}

BOOL sollang_probe_end(HANDLE file)
{
    ++end_calls;
    if (failure_mode == 2) {
        SetLastError(ERROR_DISK_FULL);
        return FALSE;
    }
    return SetEndOfFile(file);
}

static int reset_file(const char *path)
{
    HANDLE file = CreateFileA(path, GENERIC_WRITE, 0, NULL, TRUNCATE_EXISTING,
                              FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) return 0;
    DWORD written = 0;
    BOOL ok = WriteFile(file, original, sizeof original, &written, NULL);
    BOOL closed = CloseHandle(file);
    return ok && written == sizeof original && closed;
}

static int has_exact_prefix(const char *path, DWORD expected_length)
{
    HANDLE file = CreateFileA(path, GENERIC_READ, 0, NULL, OPEN_EXISTING,
                              FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) return 0;
    LARGE_INTEGER size;
    unsigned char bytes[sizeof original];
    DWORD read = 0;
    BOOL ok = GetFileSizeEx(file, &size)
        && size.QuadPart == expected_length
        && ReadFile(file, bytes, sizeof bytes, &read, NULL)
        && read == expected_length
        && memcmp(bytes, original, expected_length) == 0;
    BOOL closed = CloseHandle(file);
    return ok && closed;
}

int main(int argc, char **argv)
{
    if (argc != 2 || (strcmp(argv[1], "preserved") != 0
                      && strcmp(argv[1], "baseline-failure") != 0)) return 2;
    int expect_baseline = strcmp(argv[1], "baseline-failure") == 0;
    char directory[MAX_PATH];
    char path[MAX_PATH];
    DWORD directory_length = GetTempPathA(MAX_PATH, directory);
    if (directory_length == 0 || directory_length >= MAX_PATH
        || GetTempFileNameA(directory, "s17", 0, path) == 0) return 3;
    int passed = 0;
    for (int mode = 1; mode <= 3; ++mode) {
        if (!reset_file(path)) break;
        failure_mode = mode == 3 ? 0 : mode;
        seek_calls = 0;
        end_calls = 0;
        int mapped = sollang_probe_map(path, strlen(path), 4);
        DWORD expected_length = mode == 3 ? 4 : sizeof original;
        int expected_end_calls = mode == 1 ? 0 : 1;
        if (mode == 1 && expect_baseline) {
            expected_length = 0;
            expected_end_calls = 1;
        }
        if (mapped != (mode == 3) || seek_calls != 1
            || end_calls != expected_end_calls
            || !has_exact_prefix(path, expected_length)) {
            fprintf(stderr, "FAIL mode=%d mapped=%d seek=%d end=%d expected-length=%lu\n",
                    mode, mapped, seek_calls, end_calls, expected_length);
            break;
        }
        ++passed;
    }
    /* Only the exact path created above is ever removed. */
    if (!DeleteFileA(path)) return 4;
    if (passed != 3) return 1;
    printf("mapped resize %s: 3/3\n", argv[1]);
    return 0;
}
