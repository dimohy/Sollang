#include <new>

#if defined(_WIN32)
#define SOLLANG_CPP_EXPORT extern "C" __declspec(dllexport)
#else
#define SOLLANG_CPP_EXPORT extern "C" __attribute__((visibility("default")))
#endif

struct Counter
{
    explicit Counter(int initial) noexcept : value(initial) {}
    int add(int amount) noexcept
    {
        value += amount;
        return value;
    }
    int value;
};

struct CounterHandle
{
    unsigned long long handle;
};

static int drop_count;

SOLLANG_CPP_EXPORT CounterHandle counter_create(int initial) noexcept
{
    return { reinterpret_cast<unsigned long long>(new (std::nothrow) Counter(initial)) };
}

SOLLANG_CPP_EXPORT int counter_add(const CounterHandle* self, int amount) noexcept
{
    return reinterpret_cast<Counter*>(self->handle)->add(amount);
}

SOLLANG_CPP_EXPORT void counter_drop(unsigned long long handle) noexcept
{
    delete reinterpret_cast<Counter*>(handle);
    ++drop_count;
}

SOLLANG_CPP_EXPORT int counter_drop_count() noexcept
{
    return drop_count;
}
