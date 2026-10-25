#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <limits.h>
typedef struct { uint64_t id, capacity, count, untracked; void *records; void *untracked_head; } Session;
_Static_assert(sizeof(Session)==48, "Current private diagnostic session layout is 48 bytes");
extern void *diagnostic_start_probe(int32_t capacity, int32_t *error);
extern void diagnostic_set_next_id(uint64_t id);
extern uint64_t diagnostic_get_next_id(void);
static int fail_allocation, allocation_calls;
void *diagnostic_test_alloc(uint64_t bytes) {
    allocation_calls++;
    return fail_allocation ? NULL : malloc((size_t)bytes);
}
#define CHECK(x) do { if (!(x)) { fprintf(stderr,"check failed at line %d\n",__LINE__); return 1; } } while(0)
int main(void) {
    int32_t error;
    int32_t invalid[] = { INT_MIN, -1, 0, 65536, INT_MAX };
    for (unsigned i=0;i<sizeof(invalid)/sizeof(invalid[0]);i++) {
        CHECK(diagnostic_start_probe(invalid[i],&error)==NULL);
        CHECK(error==0 && allocation_calls==0 && diagnostic_get_next_id()==1);
    }
    fail_allocation=1;
    CHECK(diagnostic_start_probe(1,&error)==NULL);
    CHECK(error==2 && allocation_calls==1 && diagnostic_get_next_id()==1);
    fail_allocation=0;
    Session *s=diagnostic_start_probe(1,&error);
    CHECK(s && error==-1 && s->id==1 && s->capacity==1);
    CHECK(s->count==0 && s->untracked==0 && s->records==(char*)s+sizeof(Session) && s->untracked_head==NULL);
    CHECK(diagnostic_get_next_id()==2); free(s);
    s=diagnostic_start_probe(65535,&error);
    CHECK(s && error==-1 && s->id==2 && s->capacity==65535);
    CHECK(s->count==0 && s->untracked==0 && s->records==(char*)s+sizeof(Session) && s->untracked_head==NULL);
    CHECK(diagnostic_get_next_id()==3); free(s);
    diagnostic_set_next_id(UINT64_MAX);
    int previous_calls=allocation_calls;
    CHECK(diagnostic_start_probe(1,&error)==NULL);
    CHECK(error==1 && allocation_calls==previous_calls);
    CHECK(diagnostic_get_next_id()==UINT64_MAX);
    puts("diagnostic-start-boundaries=9");
    return 0;
}
