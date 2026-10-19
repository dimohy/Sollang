#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

static unsigned failed_site;

void *dictionary_failure_allocate(size_t bytes, unsigned site) {
    fprintf(stderr, "dictionary-allocation-site=%u\n", site);
    fflush(stderr);
    if (site == failed_site) return NULL;
    return malloc(bytes);
}

extern int slg_program_main(void);

int main(int argc, char **argv) {
    SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);
    if (argc != 2) return 2;
    char *end;
    unsigned long value = strtoul(argv[1], &end, 10);
    if (*end != '\0' || value > 0xffffffffUL) return 2;
    failed_site = (unsigned)value;
    return slg_program_main();
}
