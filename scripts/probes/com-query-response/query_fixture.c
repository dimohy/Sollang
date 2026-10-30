/* Reuse the retained valid fixture; only QueryInterface responses are varied. */
#define DllGetClassObject original_DllGetClassObject
#include "../../../tests/com-interop/com_fixture.c"
#undef DllGetClassObject

static int32_t query_mode = 1;

static int32_t controlled_query(Calculator *self, const Guid *iid, void **result)
{
    if (query_mode == 1)
    {
        *result = 0;
        return S_OK;
    }
    if (query_mode == 2)
    {
        /* A rejected output conveys no owned reference. */
        *result = self;
        return E_NOINTERFACE;
    }
    return calculator_query_interface(self, iid, result);
}

static const CalculatorVtable controlled_vtable =
    {controlled_query, calculator_add_ref, calculator_release, calculator_add};

EXPORT int32_t DllGetClassObject(const Guid *class_id, const Guid *iid, void **result)
{
    calculator.vtable = &controlled_vtable;
    return original_DllGetClassObject(class_id, iid, result);
}

EXPORT int32_t query_fixture_set_mode(int32_t mode)
{
    query_mode = mode;
    return mode;
}
