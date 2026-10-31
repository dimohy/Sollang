#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
typedef struct { void *ptr; size_t size; void *allocator; int live; void *frames[8]; USHORT count; unsigned char bytes[8]; } Entry;
static Entry entries[65536];
static size_t cursor;
void *sollang_alloc(uint64_t bytes) {
    void *value = HeapAlloc(GetProcessHeap(), 0, (SIZE_T)bytes);
    size_t slot = cursor++ % 65536;
    if (entries[slot].live) { fputs("audit-capacity-exhausted\n", stderr); exit(91); }
    entries[slot] = (Entry){value, (size_t)bytes, __builtin_return_address(0), value != NULL};
    return value;
}
void sollang_free(void *value) {
    if (!value) return;
    Entry *found = NULL;
    for (size_t n = cursor; n > 0 && cursor - n < 65536; --n) {
        Entry *entry = &entries[(n - 1) % 65536];
        if (entry->ptr == value) { found = entry; break; }
    }
    if ((found && !found->live) || !HeapValidate(GetProcessHeap(), 0, value)) {
        uintptr_t base = (uintptr_t)GetModuleHandleW(NULL);
        fprintf(stderr, "invalid-free ptr=%p tracked=%d live=%d bytes=%zu allocRva=%llx freeRva=%llx\n", value, found != NULL, found ? found->live : -1, found ? found->size : 0,
            (unsigned long long)(found ? (uintptr_t)found->allocator - base : 0),
            (unsigned long long)((uintptr_t)__builtin_return_address(0) - base));
        if (found) {
            fputs("first-bytes=", stderr); for (size_t i=0;i<8 && i<found->size;i++) fprintf(stderr,"%02x",found->bytes[i]); fputs("\nfirst-free-stack=",stderr);
            for(USHORT i=0;i<found->count;i++) fprintf(stderr,"%llx ",(unsigned long long)((uintptr_t)found->frames[i]-base)); fputc('\n',stderr);
        }
        void *frames[16]; USHORT count=CaptureStackBackTrace(0,16,frames,NULL); fputs("second-free-stack=",stderr);
        for(USHORT i=0;i<count;i++) fprintf(stderr,"%llx ",(unsigned long long)((uintptr_t)frames[i]-base)); fputc('\n',stderr);
        for(size_t n=cursor;n>0 && cursor-n<65536;n--) {
            Entry *prior=&entries[(n-1)%65536]; if(prior->ptr!=value) continue;
            fprintf(stderr,"history serial=%zu bytes=%zu alloc=%llx free-stack=",n,prior->size,(unsigned long long)((uintptr_t)prior->allocator-base));
            for(USHORT i=0;i<prior->count;i++) fprintf(stderr,"%llx ",(unsigned long long)((uintptr_t)prior->frames[i]-base));
            fputs(" data=",stderr);for(size_t i=0;i<8 && i<prior->size;i++) fprintf(stderr,"%02x",prior->bytes[i]);fputc('\n',stderr);
        }
        fflush(stderr); exit(90);
    }
    if (found) {
        found->count=CaptureStackBackTrace(0,8,found->frames,NULL);
        for(size_t i=0;i<8 && i<found->size;i++) found->bytes[i]=((unsigned char*)value)[i];
        found->live = 0;
    }
    HeapFree(GetProcessHeap(), 0, value);
}
