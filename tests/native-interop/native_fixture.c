#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#define SOLLANG_EXPORT __declspec(dllexport)
int _fltused = 0;
#else
#define SOLLANG_EXPORT __attribute__((visibility("default")))
#endif

SOLLANG_EXPORT int native_add(int left, int right)
{
    return left + right;
}

SOLLANG_EXPORT long long native_mul_i64(long long left, long long right)
{
    return left * right;
}

SOLLANG_EXPORT double native_hypot_squared(double left, double right)
{
    return left * left + right * right;
}

SOLLANG_EXPORT int16_t native_negate_i16(int16_t value)
{
    return (int16_t)-value;
}

SOLLANG_EXPORT uint16_t native_add_u16(uint16_t left, uint16_t right)
{
    return (uint16_t)(left + right);
}

typedef struct NativePoint
{
    double x;
    double y;
} NativePoint;

typedef struct NativeMixed
{
    int32_t tag;
    double value;
    int16_t code;
} NativeMixed;

typedef struct NativePair32
{
    int32_t left;
    int32_t right;
} NativePair32;

typedef struct NativeIntDouble
{
    int32_t tag;
    double value;
} NativeIntDouble;

typedef struct NativeFloatPair
{
    float left;
    float right;
} NativeFloatPair;

SOLLANG_EXPORT double native_point_sum(NativePoint point)
{
    return point.x + point.y;
}

SOLLANG_EXPORT double native_point_sum_ref(const NativePoint* point)
{
    return point->x + point->y;
}

SOLLANG_EXPORT void native_point_translate(NativePoint* point, double dx, double dy)
{
    point->x += dx;
    point->y += dy;
}

SOLLANG_EXPORT NativePoint native_point_make(double x, double y)
{
    NativePoint point = { x, y };
    return point;
}

SOLLANG_EXPORT int32_t native_pair32_sum(NativePair32 value)
{
    return value.left + value.right;
}

SOLLANG_EXPORT NativePair32 native_pair32_make(int32_t left, int32_t right)
{
    NativePair32 value = { left, right };
    return value;
}

SOLLANG_EXPORT double native_int_double_sum(NativeIntDouble value)
{
    return (double)value.tag + value.value;
}

SOLLANG_EXPORT NativeIntDouble native_int_double_make(int32_t tag, double value)
{
    NativeIntDouble result = { tag, value };
    return result;
}

SOLLANG_EXPORT float native_float_pair_sum(NativeFloatPair value)
{
    return value.left + value.right;
}

SOLLANG_EXPORT NativeFloatPair native_float_pair_make(float left, float right)
{
    NativeFloatPair value = { left, right };
    return value;
}

SOLLANG_EXPORT int64_t native_mixed_sum(NativeMixed value)
{
    return (int64_t)value.tag + (int64_t)value.value + (int64_t)value.code;
}

SOLLANG_EXPORT NativeMixed native_mixed_make(int32_t tag, double value, int16_t code)
{
    NativeMixed result = { tag, value, code };
    return result;
}

SOLLANG_EXPORT int32_t native_pair32_after_six(
    int32_t a,
    int32_t b,
    int32_t c,
    int32_t d,
    int32_t e,
    int32_t f,
    NativePair32 value)
{
    return a + b + c + d + e + f + value.left + value.right;
}

SOLLANG_EXPORT double native_point_after_eight(
    double a,
    double b,
    double c,
    double d,
    double e,
    double f,
    double g,
    double h,
    NativePoint value)
{
    return a + b + c + d + e + f + g + h + value.x + value.y;
}

SOLLANG_EXPORT int64_t native_point_size(void) { return (int64_t)sizeof(NativePoint); }
SOLLANG_EXPORT int64_t native_point_alignment(void) { return (int64_t)_Alignof(NativePoint); }
SOLLANG_EXPORT int64_t native_point_x_offset(void) { return (int64_t)offsetof(NativePoint, x); }
SOLLANG_EXPORT int64_t native_point_y_offset(void) { return (int64_t)offsetof(NativePoint, y); }
SOLLANG_EXPORT int64_t native_mixed_size(void) { return (int64_t)sizeof(NativeMixed); }
SOLLANG_EXPORT int64_t native_mixed_alignment(void) { return (int64_t)_Alignof(NativeMixed); }
SOLLANG_EXPORT int64_t native_mixed_tag_offset(void) { return (int64_t)offsetof(NativeMixed, tag); }
SOLLANG_EXPORT int64_t native_mixed_value_offset(void) { return (int64_t)offsetof(NativeMixed, value); }
SOLLANG_EXPORT int64_t native_mixed_code_offset(void) { return (int64_t)offsetof(NativeMixed, code); }
