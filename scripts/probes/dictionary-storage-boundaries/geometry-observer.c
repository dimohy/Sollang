#include <stdbool.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include "dictionary_geometry_expected.h"

_Static_assert(sizeof(uintptr_t) == 8, "geometry observer requires Windows x64");
static size_t current;
static unsigned char cell;
static uint64_t allocation_bytes;
static bool allocated;
static bool zeroed;

static void fail(const char *field) {
    fprintf(stderr, "dictionary-geometry:mismatch:%zu:%s\n", current, field);
    exit(17);
}

uint64_t dict_test_capacity(uint64_t capacity) {
    if (current >= expected_count || capacity != expected_rows[current].capacity)
        fail("capacity");
    volatile uint64_t observed = capacity;
    return observed;
}

void *dict_test_allocate(uint64_t bytes) {
    if (current >= expected_count || allocated || bytes != expected_rows[current].bytes)
        fail("allocation-bytes");
    allocated = true;
    allocation_bytes = bytes;
    return &cell;
}

void dict_test_zero(void *pointer, uint8_t value, uint64_t bytes, bool is_volatile) {
    if (current >= expected_count || zeroed || pointer != &cell || value != 0
        || is_volatile || bytes != expected_rows[current].capacity + 16)
        fail("controls");
    zeroed = true;
}

void dict_test_check(void *storage, void *controls, void *keys, void *values,
                     uint64_t capacity) {
    if (current >= expected_count || !allocated || !zeroed || storage != &cell)
        fail("owner");
    const struct ExpectedRow *row = &expected_rows[current];
    const uintptr_t base = (uintptr_t)storage;
    const uint64_t offset = (uint64_t)((uintptr_t)keys - base);
    if (controls != storage) fail("control-pointer");
    if (offset != row->offset) fail("keys");
    if ((uint64_t)((uintptr_t)values - base) != row->offset + expected_value_offset)
        fail("values");
    if (capacity != row->capacity) fail("capacity-value");
    printf("%" PRId32 ",%" PRIu64 ",%" PRIu64 ",%" PRIu64 "\n",
           row->length, capacity, offset, allocation_bytes);
    allocated = false;
    zeroed = false;
    ++current;
}

int dict_test_finish(int value_offset, int stride, int alignment) {
    if (current != expected_count || allocated || zeroed) fail("case-count");
    if (value_offset != expected_value_offset || stride != expected_stride
        || alignment != expected_alignment) fail("layout");
    printf("layout=%d,%d,%d\n", value_offset, stride, alignment);
    return 0;
}
