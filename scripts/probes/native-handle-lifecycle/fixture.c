#include <stdint.h>
#define EXPORT __declspec(dllexport)
typedef struct CounterHandle { uintptr_t handle; } CounterHandle;
static int32_t stored;
static int32_t released;
EXPORT CounterHandle counter_create(int32_t value) {
    stored = value;
    CounterHandle result = { (uintptr_t)&stored };
    return result;
}
EXPORT int32_t counter_try_create(int32_t value, CounterHandle *out) {
    if (value < 0) return 7;
    *out = counter_create(value);
    return 0;
}
EXPORT int32_t counter_value(const CounterHandle *value) {
    return *(const int32_t *)value->handle;
}
EXPORT void counter_drop(uintptr_t value) { if (value == (uintptr_t)&stored) ++released; }
EXPORT int32_t counter_drops(void) { return released; }
