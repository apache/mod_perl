#include "mod_perl.h"

#undef getenv /* from XSUB.h */

U32 MP_debug_level = 0;

void modperl_trace(char *func, const char *fmt, ...)
{
#ifndef WIN32 /* XXX */
    va_list args;

    if (func) {
        fprintf(stderr, "%s: ", func);
    }

    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);
#endif
}

void modperl_trace_level_set(const char *level)
{
    if (!level) {
        if (!(level = getenv("MOD_PERL_TRACE"))) {
            return;
        }
    }
    MP_debug_level = 0x0;

    if (strEQ(level, "all")) {
        MP_debug_level = 0xffffffff;
    }
    else if (isALPHA(level[0])) {
        static char debopts[] = MP_TRACE_OPTS;
        char *d;

        for (; *level && (d = strchr(debopts, *level)); level++) {
            MP_debug_level |= 1 << (d - debopts);
        }
    }
    else {
        MP_debug_level = atoi(level);
    }

    MP_debug_level |= 0x80000000;

    MP_TRACE_a_do(MP_TRACE_dump_flags());
}
