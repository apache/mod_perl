#include "modperl_apache_includes.h"
#include "apr_lib.h"
#include "modperl_trace.h"
#include "modperl_log.h"

#undef getenv /* from XSUB.h */

static apr_file_t *logfile = NULL;

#ifdef WIN32
static unsigned long debug_level = 0;
#else
unsigned long MP_debug_level = 0;
#define debug_level MP_debug_level
#endif

unsigned long modperl_debug_level(void)
{
    return debug_level;  
}

void modperl_trace(char *func, const char *fmt, ...)
{
    char vstr[8192];
    apr_size_t vstr_len = 0;
    va_list args;

    if (!logfile) {
        return;
    }

    if (func) {
        apr_file_printf(logfile, "%s: ", func);
    }

    va_start(args, fmt);
    vstr_len = apr_vsnprintf(vstr, sizeof(vstr), fmt, args);
    va_end(args);

    apr_file_write(logfile, vstr, &vstr_len);
}

void modperl_trace_level_set(server_rec *s, const char *level)
{
    if (!level) {
        if (!(level = getenv("MOD_PERL_TRACE"))) {
            return;
        }
    }
    debug_level = 0x0;

    if (strcasecmp(level, "all") == 0) {
        debug_level = 0xffffffff;
    }
    else if (apr_isalpha(level[0])) {
        static char debopts[] = MP_TRACE_OPTS;
        char *d;

        for (; *level && (d = strchr(debopts, *level)); level++) {
            debug_level |= 1 << (d - debopts);
        }
    }
    else {
        debug_level = atoi(level);
    }

    debug_level |= 0x80000000;

    logfile = s->error_log; /* XXX */

    MP_TRACE_a_do(MP_TRACE_dump_flags());
}
