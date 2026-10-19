#include <stdio.h>
#include <stdlib.h>

typedef struct AllocationRecord {
    void *value;
    size_t size;
    int id;
    struct AllocationRecord *next;
} AllocationRecord;

static AllocationRecord *live_allocations;
static int next_id = 1;

void *c437_audit_malloc(size_t size) {
    void *value = malloc(size);
    if (value == NULL) return NULL;
    AllocationRecord *record = malloc(sizeof(*record));
    if (record == NULL) exit(2);
    record->value = value;
    record->size = size;
    record->id = next_id++;
    record->next = live_allocations;
    live_allocations = record;
    printf("alloc id=%d,size=%zu,ptr=%p\n", record->id, size, value);
    return value;
}

void c437_audit_free(void *value) {
    if (value == NULL) return;
    AllocationRecord **entry = &live_allocations;
    while (*entry != NULL && (*entry)->value != value) entry = &(*entry)->next;
    if (*entry == NULL) {
        printf("invalid-free ptr=%p\n", value);
        return;
    }
    AllocationRecord *record = *entry;
    *entry = record->next;
    printf("free id=%d,size=%zu,ptr=%p\n", record->id, record->size, value);
    free(record);
    free(value);
}

void *c437_audit_realloc(void *value, size_t size) {
    if (value == NULL) return c437_audit_malloc(size);
    AllocationRecord *record = live_allocations;
    while (record != NULL && record->value != value) record = record->next;
    if (record == NULL) return NULL;
    void *replacement = realloc(value, size);
    if (replacement != NULL) {
        printf("realloc id=%d,old=%zu,new=%zu,ptr=%p\n", record->id, record->size, size, replacement);
        record->value = replacement;
        record->size = size;
    }
    return replacement;
}

extern int slg_program_main(void);

int main(void) {
    int result = slg_program_main();
    for (AllocationRecord *record = live_allocations; record != NULL; record = record->next) {
        printf("live id=%d,size=%zu,ptr=%p\n", record->id, record->size, record->value);
    }
    return result;
}
