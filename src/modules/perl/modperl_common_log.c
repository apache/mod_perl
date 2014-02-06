/* Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "modperl_common_includes.h"
#include "modperl_common_log.h"
#include "modperl_debug.h"

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

void modperl_trace_logfile_set(apr_file_t *logfile_new)
{
    logfile = logfile_new;
}

void modperl_trace(const char *func, const char *fmt, ...)
{
    char vstr[8192];
    apr_size_t vstr_len = 0;
    va_list args;

    if (!logfile) {
        return;
    }

    /* for more information on formatting codes see
       http://apr.apache.org/docs/apr/1.4/group__apr__lib.html#gad2cd3594aeaafd45931d1034965f48c1
     */

    /* PERL_GET_CONTEXT yields nonsense until the first interpreter is
     * created. Hence the modperl_is_running() question. */
    if (modperl_threaded_mpm()) {
        if (modperl_threads_started()) {
            apr_os_thread_t tid = apr_os_thread_current();
            apr_file_printf(logfile, "[pid=%lu, tid=%pt, perl=%pp] ",
                            (unsigned long)getpid(), &tid,
                            modperl_is_running() ? PERL_GET_CONTEXT : NULL);
        }
        else {
            apr_file_printf(logfile, "[pid=%lu, perl=%pp] ",
                            (unsigned long)getpid(),
                            modperl_is_running() ? PERL_GET_CONTEXT : NULL);
        }
    }
    else {
#ifdef USE_ITHREADS
        apr_file_printf(logfile, "[pid=%lu, perl=%pp] ",
                        (unsigned long)getpid(),
                        modperl_is_running() ? PERL_GET_CONTEXT : NULL);
#else
        apr_file_printf(logfile, "[pid=%lu] ", (unsigned long)getpid());
#endif
    }

    if (func && *func) {
        apr_file_printf(logfile, "%s: ", func);
    }

    va_start(args, fmt);
    vstr_len = apr_vsnprintf(vstr, sizeof(vstr), fmt, args);
    va_end(args);

    apr_file_write(logfile, vstr, &vstr_len);
    apr_file_printf(logfile, "\n");
}

void modperl_trace_level_set(apr_file_t *logfile, const char *level)
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

    modperl_trace_logfile_set(logfile);

    MP_TRACE_any_do(MP_TRACE_dump_flags());
}

/*
 * Local Variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
