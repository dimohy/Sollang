#include <stdio.h>
#include <stdlib.h>

typedef struct AllocationRecord {
    void *value;
    struct AllocationRecord *next;
} AllocationRecord;

static AllocationRecord *live_allocations;
static int allocations;
static int releases;
static int invalid_releases;

void *c437_audit_malloc(size_t size) {
    void *value = malloc(size);
    if (value == NULL) return NULL;
    AllocationRecord *record = malloc(sizeof(*record));
    if (record == NULL) {
        free(value);
        fputs("allocation audit bookkeeping failed\n", stderr);
        exit(1);
    }
    record->value = value;
    record->next = live_allocations;
    live_allocations = record;
    allocations++;
    return value;
}

void c437_audit_free(void *value) {
    if (value == NULL) return;
    AllocationRecord **entry = &live_allocations;
    while (*entry != NULL && (*entry)->value != value) entry = &(*entry)->next;
    if (*entry == NULL) {
        invalid_releases++;
        fputs("invalid release: pointer is not a live audited allocation\n", stderr);
        return;
    }
    AllocationRecord *record = *entry;
    *entry = record->next;
    free(record);
    free(value);
    releases++;
}

void *c437_audit_realloc(void *value, size_t size) {
    if (value == NULL) return c437_audit_malloc(size);
    AllocationRecord *record = live_allocations;
    while (record != NULL && record->value != value) record = record->next;
    if (record == NULL) {
        invalid_releases++;
        fputs("invalid realloc: pointer is not a live audited allocation\n", stderr);
        return NULL;
    }
    if (size == 0) {
        c437_audit_free(value);
        return NULL;
    }
    void *replacement = realloc(value, size);
    if (replacement != NULL) record->value = replacement;
    return replacement;
}

extern int slg_program_main(void);

int main(void) {
    int result = slg_program_main();
    printf("allocations=%d,releases=%d,invalid=%d\n", allocations, releases, invalid_releases);
    return result != 0 || allocations != releases || invalid_releases != 0 || live_allocations != NULL;
}
