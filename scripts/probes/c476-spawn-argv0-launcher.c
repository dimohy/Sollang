#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Start the real image with a separate argv[0]. The native driver uses argv[0]
// for its emitter child, so an absent argv[0] injects a child spawn failure.
int main(int argc, char **argv) {
    if (argc != 4) {
        fputs("c476 launcher expects image, absent argv0, and child arguments\n", stderr);
        return 97;
    }
    size_t length = strlen(argv[2]) + strlen(argv[3]) + 5;
    char *command = (char *)malloc(length);
    if (command == NULL) {
        fputs("c476 launcher allocation failed\n", stderr);
        return 98;
    }
    snprintf(command, length, "\"%s\" %s", argv[2], argv[3]);

    STARTUPINFOA start = {0};
    PROCESS_INFORMATION process = {0};
    start.cb = sizeof(start);
    start.dwFlags = STARTF_USESTDHANDLES;
    start.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
    start.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
    start.hStdError = GetStdHandle(STD_ERROR_HANDLE);
    BOOL started = CreateProcessA(argv[1], command, NULL, NULL, TRUE, CREATE_NO_WINDOW,
                                  NULL, NULL, &start, &process);
    free(command);
    if (!started) {
        fprintf(stderr, "c476 launcher could not start real compiler (%lu)\n", GetLastError());
        return 99;
    }
    WaitForSingleObject(process.hProcess, INFINITE);
    DWORD code = 0;
    if (!GetExitCodeProcess(process.hProcess, &code)) {
        fprintf(stderr, "c476 launcher could not read compiler exit (%lu)\n", GetLastError());
        code = 100;
    }
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    return (int)code;
}
