#include <stdint.h>
#include <stdio.h>
#include <windows.h>

extern uint64_t sollang_probe_poll(uint64_t token);
static HANDLE suspended_thread;

static uint64_t spawn_child(const char *command, int suspended) {
    STARTUPINFOA startup = {0};
    PROCESS_INFORMATION process = {0};
    char mutable_command[512];
    startup.cb = sizeof(startup);
    if (snprintf(mutable_command, sizeof(mutable_command), "%s", command) < 0) return 0;
    DWORD flags = suspended ? CREATE_SUSPENDED : 0;
    if (!CreateProcessA(NULL, mutable_command, NULL, NULL, FALSE, flags, NULL, NULL, &startup, &process)) return 0;
    if (suspended) suspended_thread = process.hThread;
    else CloseHandle(process.hThread);
    return (uint64_t)(uintptr_t)process.hProcess;
}

static int state(uint64_t packed) { return (int)(packed >> 32); }
static int code(uint64_t packed) { return (int)(uint32_t)packed; }

int main(void) {
    uint64_t slow = spawn_child("cmd.exe /d /c exit /b 7", 1);
    uint64_t first = sollang_probe_poll(slow);
    if (!slow || state(first) != 0) return 1;
    if (ResumeThread(suspended_thread) == (DWORD)-1) return 2;
    CloseHandle(suspended_thread);
    uint64_t finished = first;
    for (int attempt = 0; attempt < 400 && state(finished) == 0; ++attempt) {
        Sleep(10);
        finished = sollang_probe_poll(slow);
    }
    if (state(finished) != 1 || code(finished) != 7) return 2;
    if (state(sollang_probe_poll(slow)) != 2) return 3;

    uint64_t active_code = spawn_child("cmd.exe /d /c exit /b 259", 0);
    uint64_t active_result = 0;
    for (int attempt = 0; attempt < 400; ++attempt) {
        active_result = sollang_probe_poll(active_code);
        if (state(active_result) != 0) break;
        Sleep(10);
    }
    if (!active_code || state(active_result) != 1 || code(active_result) != 259) return 4;
    if (state(sollang_probe_poll(0)) != 2) return 5;
    puts("process tryWait runtime: 5/5");
    return 0;
}
