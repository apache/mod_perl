#ifndef MODPERL_GTOP_H
#define MODPERL_GTOP_H

#ifndef MP_TRACE
#    undef MP_USE_GTOP
#endif

#ifdef MP_USE_GTOP

#include <glibtop.h>
#include <glibtop/open.h>
#include <glibtop/close.h>
#include <glibtop/xmalloc.h>
#include <glibtop/parameter.h>
#include <glibtop/union.h>
#include <glibtop/sysdeps.h>

#define MP_GTOP_SSS 16

typedef struct {
    char size[MP_GTOP_SSS];
    char vsize[MP_GTOP_SSS];
    char resident[MP_GTOP_SSS];
    char share[MP_GTOP_SSS];
    char rss[MP_GTOP_SSS];
} modperl_gtop_proc_mem_ss;
    
typedef struct {
    glibtop_union before;
    glibtop_union after;
    pid_t pid;
    modperl_gtop_proc_mem_ss proc_mem_ss;
} modperl_gtop_t;

modperl_gtop_t *modperl_gtop_new(apr_pool_t *p);
void modperl_gtop_get_proc_mem_before(modperl_gtop_t *gtop);
void modperl_gtop_get_proc_mem_after(modperl_gtop_t *gtop);
void modperl_gtop_report_proc_mem(modperl_gtop_t *gtop, 
                                  char *when, char *msg);
void modperl_gtop_report_proc_mem_diff(modperl_gtop_t *gtop, char *msg);
void modperl_gtop_report_proc_mem_before(modperl_gtop_t *gtop, char *msg);
void modperl_gtop_report_proc_mem_after(modperl_gtop_t *gtop, char *msg);

#define modperl_gtop_do_proc_mem_before(msg) \
        modperl_gtop_get_proc_mem_before(scfg->gtop); \
        modperl_gtop_report_proc_mem_before(scfg->gtop, msg)

#define modperl_gtop_do_proc_mem_after(msg) \
        modperl_gtop_get_proc_mem_after(scfg->gtop); \
        modperl_gtop_report_proc_mem_after(scfg->gtop, msg); \
        modperl_gtop_report_proc_mem_diff(scfg->gtop, msg)

#endif /* MP_USE_GTOP */

#endif /* MODPERL_GTOP_H */
