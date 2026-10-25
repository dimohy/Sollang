struct ExpectedRow { int32_t length; uint64_t capacity, offset, bytes; };
static const struct ExpectedRow expected_rows[] = {
    {0, UINT64_C(4), UINT64_C(24), UINT64_C(56)},
    {1, UINT64_C(4), UINT64_C(24), UINT64_C(56)},
    {2, UINT64_C(4), UINT64_C(24), UINT64_C(56)},
    {3, UINT64_C(8), UINT64_C(24), UINT64_C(88)},
    {4, UINT64_C(8), UINT64_C(24), UINT64_C(88)},
    {5, UINT64_C(16), UINT64_C(32), UINT64_C(160)},
    {7, UINT64_C(16), UINT64_C(32), UINT64_C(160)},
    {8, UINT64_C(16), UINT64_C(32), UINT64_C(160)},
    {9, UINT64_C(32), UINT64_C(48), UINT64_C(304)},
    {1073741823, UINT64_C(2147483648), UINT64_C(2147483664), UINT64_C(19327352848)},
    {1073741824, UINT64_C(2147483648), UINT64_C(2147483664), UINT64_C(19327352848)},
    {2147483647, UINT64_C(4294967296), UINT64_C(4294967312), UINT64_C(38654705680)},
};
static const size_t expected_count = 12;
static const int expected_value_offset = 4;
static const int expected_stride = 8;
static const int expected_alignment = 4;
