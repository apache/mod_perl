#ifdef MP_USE_GTOP

#include "mod_perl.h"

int modperl_gtop_size_string(size_t size, char *size_string)
{
    if (size == (size_t)-1) {
        ap_snprintf(size_string, MP_GTOP_SSS, "-");
    }
    else if (!size) {
        ap_snprintf(size_string, MP_GTOP_SSS, "0k");
    }
    else if (size < 1024) {
	ap_snprintf(size_string, MP_GTOP_SSS, "1k");
    }
    else if (size < 1048576) {
	ap_snprintf(size_string, MP_GTOP_SSS, "%dk",
                    (size + 512) / 1024);
    }
    else if (size < 103809024) {
	ap_snprintf(size_string, MP_GTOP_SSS, "%.1fM",
                    size / 1048576.0);
    }
    else {
	ap_snprintf(size_string, MP_GTOP_SSS, "%dM",
                    (size + 524288) / 1048576);
    }

    return 1;
}

ap_status_t modperl_gtop_exit(void *data)
{
    glibtop_close();
    return APR_SUCCESS;
}

modperl_gtop_t *modperl_gtop_new(ap_pool_t *p)
{
    modperl_gtop_t *gtop = 
        (modperl_gtop_t *)ap_pcalloc(p, sizeof(*gtop));

    gtop->pid = getpid();
    glibtop_init();
    ap_register_cleanup(p, NULL,
                        modperl_gtop_exit, ap_null_cleanup);

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
void modperl_gtop_proc_mem_size_string(modperl_gtop_t *gtop, int type)
{
    int is_diff = (type == SS_TYPE_DIFF);
    glibtop_proc_mem *pm;

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
                                  char *when, char *msg)
{
#define ss_item(item) gtop->proc_mem_ss.item

    fprintf(stderr, "%s %s: " ss_fmt "\n",
            msg, when,
            ss_item(size),
            ss_item(vsize),
            ss_item(resident),
            ss_item(share),
            ss_item(rss));

#undef ss_item
}

void modperl_gtop_report_proc_mem_diff(modperl_gtop_t *gtop, char *msg)
{
    modperl_gtop_proc_mem_size_string(gtop, SS_TYPE_DIFF);
    modperl_gtop_report_proc_mem(gtop, "diff", msg);
}

void modperl_gtop_report_proc_mem_before(modperl_gtop_t *gtop, char *msg)
{
    modperl_gtop_proc_mem_size_string(gtop, SS_TYPE_BEFORE);
    modperl_gtop_report_proc_mem(gtop, "before", msg);
}

void modperl_gtop_report_proc_mem_after(modperl_gtop_t *gtop, char *msg)
{
    modperl_gtop_proc_mem_size_string(gtop, SS_TYPE_AFTER);
    modperl_gtop_report_proc_mem(gtop, "after", msg);
}

#endif /* MP_USE_GTOP */
