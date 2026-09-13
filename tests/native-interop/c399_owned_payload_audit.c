#include <stdint.h>
#include <stdlib.h>

#if defined(_WIN32)
#define SOLLANG_EXPORT __declspec(dllexport)
#else
#define SOLLANG_EXPORT __attribute__((visibility("default")))
#endif

typedef struct C399Owner {
    uint64_t handle;
} C399Owner;

static int32_t allocations;
static int32_t releases;
static int32_t invalid_releases;
static uint64_t active_handles[64];

SOLLANG_EXPORT C399Owner c399_owner_create(int32_t value) {
    int32_t *storage = (int32_t *)malloc(sizeof(int32_t));
    if (storage == NULL) {
        return (C399Owner){0};
    }
    *storage = value;
    allocations += 1;
    active_handles[allocations - 1] = (uint64_t)(uintptr_t)storage;
    return (C399Owner){(uint64_t)(uintptr_t)storage};
}

SOLLANG_EXPORT int32_t c399_owner_value(const C399Owner *owner) {
    return owner == NULL || owner->handle == 0
        ? -1
        : *(const int32_t *)(uintptr_t)owner->handle;
}

SOLLANG_EXPORT void c399_owner_drop(uint64_t handle) {
    if (handle == 0) {
        return;
    }
    int32_t found = 0;
    for (int32_t index = 0; index < allocations; index += 1) {
        if (active_handles[index] == handle) {
            active_handles[index] = 0;
            found = 1;
            break;
        }
    }
    if (!found) {
        invalid_releases += 1;
        return;
    }
    free((void *)(uintptr_t)handle);
    releases += 1;
}

SOLLANG_EXPORT int32_t c399_owner_allocations(void) {
    return allocations;
}

SOLLANG_EXPORT int32_t c399_owner_releases(void) {
    return releases;
}

SOLLANG_EXPORT int32_t c399_owner_invalid_releases(void) {
    return invalid_releases;
}
