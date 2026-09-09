#include <stdio.h>
#include <stdlib.h>

#ifndef EXPECTED_ALLOCATIONS
#error Define EXPECTED_ALLOCATIONS for the audited fixture.
#endif

static int allocations;
static int releases;
static int invalid_releases;

struct allocation_record {
    void *value;
    struct allocation_record *next;
};

static struct allocation_record *live_allocations;

void *audit_malloc(size_t size) {
    void *value = malloc(size);
    if (value != NULL) {
        struct allocation_record *record = malloc(sizeof(*record));
        if (record == NULL) {
            free(value);
            fputs("allocation audit could not track an allocation\n", stderr);
            exit(1);
        }
        record->value = value;
        record->next = live_allocations;
        live_allocations = record;
        allocations++;
    }
    return value;
}

void audit_free(void *value) {
    if (value == NULL) return;
    struct allocation_record **entry = &live_allocations;
    while (*entry != NULL && (*entry)->value != value) entry = &(*entry)->next;
    if (*entry == NULL) {
        invalid_releases++;
        fputs("invalid release: pointer is not a live audited allocation\n", stderr);
        return;
    }
    struct allocation_record *record = *entry;
    *entry = record->next;
    free(record);
    releases++;
    free(value);
}

void *audit_realloc(void *value, size_t size) {
    if (value == NULL) return audit_malloc(size);
    struct allocation_record *record = live_allocations;
    while (record != NULL && record->value != value) record = record->next;
    if (record == NULL) {
        fputs("invalid realloc: pointer is not a live audited allocation\n", stderr);
        exit(1);
    }
    if (size == 0) {
        audit_free(value);
        return NULL;
    }
    void *replacement = realloc(value, size);
    if (replacement != NULL) record->value = replacement;
    return replacement;
}

extern int slg_program_main(void);

int main(void) {
    int result = slg_program_main();
    printf("allocations=%d,releases=%d\n", allocations, releases);
    return result != 0 || allocations != EXPECTED_ALLOCATIONS
        || releases != EXPECTED_ALLOCATIONS || invalid_releases != 0;
}
