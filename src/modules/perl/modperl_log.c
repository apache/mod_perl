#include "mod_perl.h"

U32 MP_debug_level = 0;

void modperl_trace(char *func, const char *fmt, ...)
{
    va_list args;

    if (func) {
        fprintf(stderr, "%s: ", func);
    }

    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);
}

void modperl_trace_level_set(char *level)
{
    if (!level) {
        if (!(level = getenv("MOD_PERL_TRACE"))) {
            return;
        }
    }
    
    if (strEQ(level, "all")) {
        MP_debug_level = 0xffffffff;
    }
    else if (isALPHA(level[0])) {
        static char debopts[] = "dshgc";
        char *d;

        for (; *level && (d = strchr(debopts, *level)); level++) {
            MP_debug_level |= 1 << (d - debopts);
        }
    }
    else {
        MP_debug_level = atoi(level);
    }

    MP_debug_level |= 0x80000000;
}
