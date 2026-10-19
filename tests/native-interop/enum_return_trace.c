#include <stdio.h>
#include <stdint.h>

void audit_enum_return(int tag, int site) {
    if (tag != 0) fprintf(stderr, "enum-return=%d,tag=%d\n", site, tag);
}

void audit_view_hash(const unsigned char *bytes, uint64_t length, int site) {
    uint64_t hash = UINT64_C(14695981039346656037);
    for (uint64_t index = 0; index < length; index++) {
        hash ^= bytes[index];
        hash *= UINT64_C(1099511628211);
    }
    fprintf(stderr, "view-return=%d,length=%llu,fingerprint=%016llx\n", site,
            (unsigned long long)length, (unsigned long long)hash);
}
