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

#include "mod_perl.h"

#ifdef MP_USE_GTOP

static int modperl_gtop_size_string(size_t size, char *size_string)
{
    if (size == (size_t)-1) {
        apr_snprintf(size_string, MP_GTOP_SSS, "-");
    }
    else if (!size) {
        apr_snprintf(size_string, MP_GTOP_SSS, "0k");
    }
    else if (size < 1024) {
        apr_snprintf(size_string, MP_GTOP_SSS, "1k");
    }
    else if (size < 1048576) {
        apr_snprintf(size_string, MP_GTOP_SSS, "%dk",
                     (int)(size + 512) / 1024);
    }
    else if (size < 103809024) {
        apr_snprintf(size_string, MP_GTOP_SSS, "%.1fM",
                     size / 1048576.0);
    }
    else {
        apr_snprintf(size_string, MP_GTOP_SSS, "%dM",
                     (int)(size + 524288) / 1048576);
    }

    return 1;
}

static apr_status_t modperl_gtop_exit(void *data)
{
    glibtop_close();
    return APR_SUCCESS;
}

modperl_gtop_t *modperl_gtop_new(apr_pool_t *p)
{
    modperl_gtop_t *gtop =
        (modperl_gtop_t *)apr_pcalloc(p, sizeof(*gtop));

    gtop->pid = getpid();
    glibtop_init();
    apr_pool_cleanup_register(p, NULL,
                              modperl_gtop_exit, apr_pool_cleanup_null);

    return gtop;
}

void modperl_gtop_get_proc_mem_before(modperl_gtop_t *gtop)
{
    glibtop_get_proc_mem(&gtop->before.proc_mem, gtop->pid);
}

void modperl_gtop_get_proc_mem_after(modperl_gtop_t *gtop)
{
    glibtop_get_proc_mem(&gtop->after.proc_mem, gtop->pid);
}

#define modperl_gtop_diff(item) \
(gtop->after.item - gtop->before.item)

#define ss_fmt "size=%s, vsize=%s, resident=%s, share=%s, rss=%s"

#define SS_TYPE_BEFORE 1
#define SS_TYPE_AFTER  2
#define SS_TYPE_DIFF   3

/*
 * XXX: this is pretty ugly,
 * but avoids allocating buffers for the size string
 */
static void modperl_gtop_proc_mem_size_string(modperl_gtop_t *gtop, int type)
{
    int is_diff = (type == SS_TYPE_DIFF);
    glibtop_proc_mem *pm = NULL;

    if (!is_diff) {
        pm = (type == SS_TYPE_BEFORE) ?
            &gtop->before.proc_mem : &gtop->after.proc_mem;
    }

#define ss_call(item) \
    modperl_gtop_size_string(is_diff ? \
                             modperl_gtop_diff(proc_mem.item) : pm->item, \
                             gtop->proc_mem_ss.item)

    ss_call(size);
    ss_call(vsize);
    ss_call(resident);
    ss_call(share);
    ss_call(rss);
#undef ss_call
}

void modperl_gtop_report_proc_mem(modperl_gtop_t *gtop,
                                  char *when, const char *func, char *msg)
{
#define ss_item(item) gtop->proc_mem_ss.item

    fprintf(stderr, "%s : %s %s: " ss_fmt "\n",
            func, (msg ? msg : ""), when,
            ss_item(size),
            ss_item(vsize),
            ss_item(resident),
            ss_item(share),
            ss_item(rss));

#undef ss_item
}

void modperl_gtop_report_proc_mem_diff(modperl_gtop_t *gtop, const char *func, char *msg)
{
    modperl_gtop_proc_mem_size_string(gtop, SS_TYPE_DIFF);
    modperl_gtop_report_proc_mem(gtop, "diff", func, msg);
}

void modperl_gtop_report_proc_mem_before(modperl_gtop_t *gtop, const char *func, char *msg)
{
    modperl_gtop_proc_mem_size_string(gtop, SS_TYPE_BEFORE);
    modperl_gtop_report_proc_mem(gtop, "before", func, msg);
}

void modperl_gtop_report_proc_mem_after(modperl_gtop_t *gtop, const char *func, char *msg)
{
    modperl_gtop_proc_mem_size_string(gtop, SS_TYPE_AFTER);
    modperl_gtop_report_proc_mem(gtop, "after", func, msg);
}

#endif /* MP_USE_GTOP */
