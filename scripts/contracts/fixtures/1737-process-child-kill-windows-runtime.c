#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <windows.h>

extern bool sollang_probe_kill(uint64_t token);

int main(void) {
    int passed = 0;
    if (!sollang_probe_kill(0)) {
        passed++;
    }

    STARTUPINFOW startup = {0};
    PROCESS_INFORMATION process = {0};
    wchar_t command[] = L"cmd.exe /d /c ping -n 30 127.0.0.1 >nul";
    startup.cb = sizeof(startup);
    if (!CreateProcessW(NULL, command, NULL, NULL, FALSE, CREATE_NO_WINDOW,
            NULL, NULL, &startup, &process)) {
        return 1;
    }
    CloseHandle(process.hThread);

    if (sollang_probe_kill((uint64_t)(uintptr_t)process.hProcess)) {
        passed++;
    }
    if (WaitForSingleObject(process.hProcess, 5000) == WAIT_OBJECT_0) {
        passed++;
    }
    CloseHandle(process.hProcess);

    if (passed != 3) {
        return 2;
    }
    puts("process kill windows runtime: 3/3");
    return 0;
}
