#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#pragma comment(lib, "ws2_32.lib")

extern int32_t socket_probe_submit(void *state, int32_t *code);
extern int32_t socket_probe_remove(void *state, int64_t *socket);
static int fail_mode, mode_calls, unexpected_waiter_calls;

/* Only this external failure boundary is injected. Association uses Windows. */
int32_t socket_probe_notification_modes(void *handle, unsigned char flags) {
    ++mode_calls;
    if (flags != 3) { SetLastError(ERROR_INVALID_PARAMETER); return 0; }
    if (fail_mode) { SetLastError(ERROR_NOT_SUPPORTED); return 0; }
    return SetFileCompletionNotificationModes(handle, flags);
}
int sollang_platform_io_ensure_signal(void) {
    ++unexpected_waiter_calls;
    return 0;
}
DWORD WINAPI sollang_socket_completion_waiter(void *state) {
    (void)state;
    ++unexpected_waiter_calls;
    return 0;
}

static int run_case(int mode, int expected_remove, int retry, int expected_calls) {
    /* Exact production offsets: state96, registration32, pending128 bytes. */
    uint64_t state[12] = {0}, registration[4] = {1, 17, 0, 0};
    uint64_t pending[16] = {0};
    HANDLE port = CreateIoCompletionPort(INVALID_HANDLE_VALUE, NULL, 0, 0);
    SOCKET stream = WSASocketW(AF_INET, SOCK_STREAM, IPPROTO_TCP, NULL, 0,
                              WSA_FLAG_OVERLAPPED);
    if (!port || stream == INVALID_SOCKET) return 0;
    registration[2] = (uint64_t)stream;
    state[0] = (uintptr_t)port;
    state[1] = (uintptr_t)registration;
    state[2] = (uintptr_t)pending;
    state[4] = state[5] = state[7] = 1;
    /* Submit's waiter lifetime is outside this extracted association test. */
    state[9] = 1;
    mode_calls = 0;
    fail_mode = mode == 1;
    int32_t code = 0, submitted = 0;
    if (mode) submitted = socket_probe_submit(state, &code);
    int ok = !mode || (submitted >= 0 && (mode != 1 || code == ERROR_NOT_SUPPORTED));
    if (retry) {
        fail_mode = 0;
        socket_probe_submit(state, &code);
        ok = ok && mode_calls == expected_calls;
    }
    int64_t returned = -1;
    int removed = socket_probe_remove(state, &returned) == -1;
    printf("mode=%d retry=%d removed=%d associated=%llu calls=%d code=%d\n",
           mode, retry, removed, (unsigned long long)registration[3], mode_calls, code);
    ok = ok && removed == expected_remove && !unexpected_waiter_calls
        && mode_calls == expected_calls;
    if (mode && !expected_remove)
        ok = ok && registration[3] == (mode == 1 && !retry ? 1u : 3u);
    if (removed) ok = ok && returned == (int64_t)stream && state[7] == 0;
    else ok = ok && registration[0] == 1 && state[7] == 1;
    ok = ok && state[8] == 0 && pending[0] == 0;
    closesocket(stream);
    CloseHandle(port);
    return ok;
}

int main(int argc, char **argv) {
    WSADATA data;
    if (WSAStartup(MAKEWORD(2, 2), &data)) return 1;
    int baseline = argc == 2 && strcmp(argv[1], "baseline-failure") == 0;
    int ok = run_case(0, 1, 0, 0);
    ok = run_case(2, 0, 0, 1) && ok;
    ok = run_case(1, baseline ? 1 : 0, 0, 1) && ok;
    ok = run_case(1, baseline ? 1 : 0, 1, baseline ? 1 : 2) && ok;
    WSACleanup();
    return ok ? 0 : 2;
}
