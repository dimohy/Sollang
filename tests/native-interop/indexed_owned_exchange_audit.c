#include <stdio.h>
#include <stdlib.h>

struct allocation_record {
    void *value;
    struct allocation_record *next;
};

static int allocations;
static int releases;
static int invalid_releases;
static struct allocation_record *live_allocations;

void *audit_malloc(size_t size) {
    void *value = malloc(size);
    if (value == NULL) return NULL;
    struct allocation_record *record = malloc(sizeof(*record));
    if (record == NULL) {
        free(value);
        return NULL;
    }
    record->value = value;
    record->next = live_allocations;
    live_allocations = record;
    allocations++;
    return value;
}

void audit_free(void *value) {
    if (value == NULL) return;
    struct allocation_record **entry = &live_allocations;
    while (*entry != NULL && (*entry)->value != value) entry = &(*entry)->next;
    if (*entry == NULL) {
        invalid_releases++;
        return;
    }
    struct allocation_record *record = *entry;
    *entry = record->next;
    free(record);
    free(value);
    releases++;
}

extern int slg_program_main(void);

int main(void) {
    int result = slg_program_main();
    printf("allocations=%d,releases=%d,invalid=%d\n", allocations, releases, invalid_releases);
    return result != 0 || allocations != releases || invalid_releases != 0 || live_allocations != NULL;
}
