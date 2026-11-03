#include <stdint.h>
#define EXPORT __declspec(dllexport)
static int32_t stored;
static int32_t released;
EXPORT void *counter_create(int32_t value) { stored = value; return &stored; }
EXPORT int32_t counter_try_create(int32_t value, void **out) {
    if (value < 0) return 7;
    *out = counter_create(value);
    return 0;
}
EXPORT int32_t counter_value(const void *value) { return *(const int32_t *)value; }
EXPORT void counter_drop(void *value) { if (value == &stored) ++released; }
EXPORT int32_t counter_drops(void) { return released; }
