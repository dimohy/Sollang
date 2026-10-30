#include <windows.h>

extern int slg_program_main(void);

int main(int argc, char **argv) {
    (void)argv;
    if (argc > 1 && !SetStdHandle(STD_OUTPUT_HANDLE, NULL)) return 200;
    return slg_program_main();
}
