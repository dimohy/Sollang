#pragma once

namespace sollang_fixture
{
inline int add(int left, int right) noexcept
{
    return left + right;
}

inline long long multiply(long long left, long long right) noexcept
{
    return left * right;
}

inline double hypot_squared(double left, double right) noexcept
{
    return left * left + right * right;
}

inline int scale(int value, int factor) noexcept
{
    return value * factor;
}

inline double scale(double value, double factor) noexcept
{
    return value * factor;
}

class Counter
{
public:
    explicit Counter(int initial) noexcept : value_(initial) {}

    int add(int amount) noexcept
    {
        value_ += amount;
        return value_;
    }

    int value() const noexcept
    {
        return value_;
    }

private:
    int value_;
};
}
