#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

struct entry {
    void *pointer;
    unsigned allocation_site;
    unsigned release_site;
    int live;
    struct entry *next;
};
static struct entry *buckets[65536];
static unsigned allocations, releases, invalid_releases;
struct site_count {
    unsigned site, allocations, releases;
    struct site_count *next;
};
static struct site_count *site_counts;

static struct site_count *count_site(unsigned site) {
    struct site_count *count = site_counts;
    while (count != NULL && count->site != site) count = count->next;
    if (count == NULL) {
        count = calloc(1, sizeof(*count));
        if (count == NULL) exit(2);
        count->site = site;
        count->next = site_counts;
        site_counts = count;
    }
    return count;
}

static struct entry *find(void *pointer, int create) {
    unsigned bucket = (unsigned)(((uintptr_t)pointer >> 4) & 65535);
    struct entry *record = buckets[bucket];
    while (record != NULL && record->pointer != pointer) record = record->next;
    if (record == NULL && create) {
        record = calloc(1, sizeof(*record));
        if (record == NULL) exit(2);
        record->pointer = pointer;
        record->next = buckets[bucket];
        buckets[bucket] = record;
    }
    return record;
}

void *audit_malloc_site(size_t size, unsigned site) {
    void *pointer = malloc(size);
    if (pointer != NULL) {
        struct entry *record = find(pointer, 1);
        record->allocation_site = site;
        record->release_site = 0;
        record->live = 1;
        allocations++;
        count_site(site)->allocations++;
    }
    return pointer;
}

void audit_free_site(void *pointer, unsigned site) {
    if (pointer == NULL) return;
    struct entry *record = find(pointer, 0);
    if (record == NULL || !record->live) {
        fprintf(stderr, "invalid-free=%u,allocation=%u,previous-free=%u\n", site,
                record == NULL ? 0 : record->allocation_site,
                record == NULL ? 0 : record->release_site);
        invalid_releases++;
        return;
    }
    record->live = 0;
    record->release_site = site;
    releases++;
    count_site(site)->releases++;
    free(pointer);
}

void *audit_realloc(void *pointer, size_t size) {
    if (pointer == NULL) return audit_malloc_site(size, 0);
    struct entry *record = find(pointer, 0);
    if (record == NULL || !record->live) {
        fputs("invalid-realloc\n", stderr);
        invalid_releases++;
        return NULL;
    }
    if (size == 0) {
        audit_free_site(pointer, 0);
        return NULL;
    }
    unsigned origin = record->allocation_site;
    void *replacement = realloc(pointer, size);
    if (replacement != NULL) {
        record->live = 0;
        record = find(replacement, 1);
        record->allocation_site = origin;
        record->release_site = 0;
        record->live = 1;
    }
    return replacement;
}

extern int slg_program_main(void);
int main(void) {
    int exit_code = slg_program_main();
    unsigned live = 0;
    for (unsigned bucket = 0; bucket < 65536; bucket++) {
        for (struct entry *record = buckets[bucket]; record != NULL; record = record->next) {
            if (record->live) {
                live++;
                fprintf(stderr, "live-allocation=%u\n", record->allocation_site);
            }
        }
    }
    printf("allocations=%u,releases=%u,invalid=%u,live=%u\n",
           allocations, releases, invalid_releases, live);
    for (struct site_count *count = site_counts; count != NULL; count = count->next)
        fprintf(stderr, "site-count=%u,allocations=%u,releases=%u\n",
                count->site, count->allocations, count->releases);
    return exit_code != 0 || invalid_releases != 0 || live != 0;
}
