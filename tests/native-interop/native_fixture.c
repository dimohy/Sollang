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
