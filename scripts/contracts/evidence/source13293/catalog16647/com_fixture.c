#include <stdint.h>

#define EXPORT __declspec(dllexport)
#define S_OK ((int32_t)0)
#define E_NOINTERFACE ((int32_t)0x80004002u)
#define E_POINTER ((int32_t)0x80004003u)
#define CLASS_E_NOAGGREGATION ((int32_t)0x80040110u)
#define CLASS_E_CLASSNOTAVAILABLE ((int32_t)0x80040111u)

typedef struct Guid
{
    uint32_t data1;
    uint16_t data2;
    uint16_t data3;
    uint8_t data4[8];
} Guid;

typedef struct Calculator Calculator;
typedef struct CalculatorVtable CalculatorVtable;
typedef struct ClassFactory ClassFactory;
typedef struct ClassFactoryVtable ClassFactoryVtable;

struct Calculator
{
    const CalculatorVtable *vtable;
    volatile uint32_t references;
};

struct CalculatorVtable
{
    int32_t (*query_interface)(Calculator *, const Guid *, void **);
    uint32_t (*add_ref)(Calculator *);
    uint32_t (*release)(Calculator *);
    int32_t (*add)(Calculator *, int32_t, int32_t, int32_t *);
};

struct ClassFactory
{
    const ClassFactoryVtable *vtable;
    volatile uint32_t references;
};

struct ClassFactoryVtable
{
    int32_t (*query_interface)(ClassFactory *, const Guid *, void **);
    uint32_t (*add_ref)(ClassFactory *);
    uint32_t (*release)(ClassFactory *);
    int32_t (*create_instance)(ClassFactory *, void *, const Guid *, void **);
    int32_t (*lock_server)(ClassFactory *, int32_t);
};

static const Guid clsid_calculator =
    {0x8A90E2A5u, 0x7A2Du, 0x4E2Au, {0x98u, 0xA0u, 0x6Bu, 0x5Cu, 0x2Au, 0x12u, 0xC5u, 0x01u}};
static const Guid iid_calculator =
    {0x4C10A47Bu, 0x725Du, 0x41D3u, {0xB5u, 0xA6u, 0x70u, 0xD6u, 0x7Du, 0x3Bu, 0xEBu, 0x11u}};
static const Guid iid_arithmetic =
    {0xB214A96Du, 0x58CFu, 0x4311u, {0xA2u, 0x9Bu, 0x6Du, 0xF8u, 0x50u, 0x80u, 0x1Cu, 0x74u}};
static const Guid iid_unknown =
    {0x00000000u, 0x0000u, 0x0000u, {0xC0u, 0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x46u}};
static const Guid iid_class_factory =
    {0x00000001u, 0x0000u, 0x0000u, {0xC0u, 0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x46u}};

static int guid_equal(const Guid *left, const Guid *right)
{
    const uint8_t *left_bytes = (const uint8_t *)left;
    const uint8_t *right_bytes = (const uint8_t *)right;
    for (uint32_t index = 0; index < 16; index++)
    {
        if (left_bytes[index] != right_bytes[index])
        {
            return 0;
        }
    }
    return 1;
}

static uint32_t calculator_add_ref(Calculator *self)
{
    return __atomic_add_fetch(&self->references, 1u, __ATOMIC_RELAXED);
}

static uint32_t calculator_release(Calculator *self)
{
    return __atomic_sub_fetch(&self->references, 1u, __ATOMIC_RELAXED);
}

static int32_t calculator_query_interface(Calculator *self, const Guid *iid, void **result)
{
    if (result == 0)
    {
        return E_POINTER;
    }
    *result = 0;
    if (!guid_equal(iid, &iid_unknown)
        && !guid_equal(iid, &iid_calculator)
        && !guid_equal(iid, &iid_arithmetic))
    {
        return E_NOINTERFACE;
    }
    calculator_add_ref(self);
    *result = self;
    return S_OK;
}

static int32_t calculator_add(Calculator *self, int32_t left, int32_t right, int32_t *result)
{
    (void)self;
    if (result == 0)
    {
        return E_POINTER;
    }
    *result = left + right;
    return S_OK;
}

static const CalculatorVtable calculator_vtable =
    {calculator_query_interface, calculator_add_ref, calculator_release, calculator_add};
static Calculator calculator = {&calculator_vtable, 0u};

static uint32_t factory_add_ref(ClassFactory *self)
{
    return __atomic_add_fetch(&self->references, 1u, __ATOMIC_RELAXED);
}

static uint32_t factory_release(ClassFactory *self)
{
    return __atomic_sub_fetch(&self->references, 1u, __ATOMIC_RELAXED);
}

static int32_t factory_query_interface(ClassFactory *self, const Guid *iid, void **result)
{
    if (result == 0)
    {
        return E_POINTER;
    }
    *result = 0;
    if (!guid_equal(iid, &iid_unknown) && !guid_equal(iid, &iid_class_factory))
    {
        return E_NOINTERFACE;
    }
    factory_add_ref(self);
    *result = self;
    return S_OK;
}

static int32_t factory_create_instance(
    ClassFactory *self,
    void *outer,
    const Guid *iid,
    void **result)
{
    (void)self;
    if (outer != 0)
    {
        return CLASS_E_NOAGGREGATION;
    }
    return calculator_query_interface(&calculator, iid, result);
}

static int32_t factory_lock_server(ClassFactory *self, int32_t lock)
{
    (void)self;
    (void)lock;
    return S_OK;
}

static const ClassFactoryVtable factory_vtable =
    {factory_query_interface, factory_add_ref, factory_release, factory_create_instance, factory_lock_server};
static ClassFactory factory = {&factory_vtable, 0u};

EXPORT int32_t DllGetClassObject(const Guid *class_id, const Guid *iid, void **result)
{
    if (!guid_equal(class_id, &clsid_calculator))
    {
        if (result != 0)
        {
            *result = 0;
        }
        return CLASS_E_CLASSNOTAVAILABLE;
    }
    return factory_query_interface(&factory, iid, result);
}

EXPORT int32_t com_fixture_live_references(void)
{
    return (int32_t)calculator.references;
}

EXPORT int32_t com_fixture_live_references_after(int32_t dependency)
{
    (void)dependency;
    return (int32_t)calculator.references;
}

int _fltused = 0;
