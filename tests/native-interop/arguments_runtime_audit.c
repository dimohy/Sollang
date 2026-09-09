#include <windows.h>
#ifndef FAIL_ALLOCATION
#define FAIL_ALLOCATION 0
#endif
#ifndef FAIL_CONVERSION
#define FAIL_CONVERSION 0
#endif
#define audit_malloc tracked_malloc
#include "owned_array_audit.c"
#undef audit_malloc
static int allocation_attempts;
static int conversion_attempts;
void *audit_malloc(size_t size) {
    if (++allocation_attempts == FAIL_ALLOCATION) return NULL;
    return tracked_malloc(size);
}
int audit_WideCharToMultiByte(UINT page, DWORD flags, LPCWCH input, int length,
    LPSTR output, int capacity, LPCCH fallback, LPBOOL used) {
    if (++conversion_attempts == FAIL_CONVERSION) return 0;
    return WideCharToMultiByte(page, flags, input, length, output, capacity, fallback, used);
}
