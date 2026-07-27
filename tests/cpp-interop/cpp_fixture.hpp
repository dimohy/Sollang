#pragma once

namespace sollang_fixture
{
inline int risky_counter_destructions = 0;

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

inline int risky_double(int value)
{
    if (value < 0)
    {
        throw value;
    }
    return value * 2;
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

class RiskyCounter
{
public:
    explicit RiskyCounter(int initial) : value_(initial)
    {
        if (initial < 0)
        {
            throw initial;
        }
    }

    ~RiskyCounter() noexcept
    {
        ++risky_counter_destructions;
    }

    int add(int amount)
    {
        if (amount == 13)
        {
            throw amount;
        }
        value_ += amount;
        return value_;
    }

private:
    int value_;
};

inline int risky_destructions() noexcept
{
    return risky_counter_destructions;
}
}
