#ifndef MODPERL_LOG_H
#define MODPERL_LOG_H

#ifdef MP_TRACE
#   if defined(__GNUC__)
#      if (__GNUC__ > 2)
#         define MP_FUNC __func__
#      else
#         define MP_FUNC __FUNCTION__
#      endif
#   else
#      define MP_FUNC NULL
#   endif
#else
#   define MP_FUNC NULL
#endif

#include "modperl_trace.h"

#ifdef _PTHREAD_H
#define modperl_thread_self() pthread_self()
#else
#define modperl_thread_self() 0
#endif

#define MP_TIDF \
(unsigned long)modperl_thread_self()

unsigned long modperl_debug_level(void);

#ifdef WIN32
#define MP_debug_level modperl_debug_level()
#else
extern unsigned long MP_debug_level;
#endif

void modperl_trace(const char *func, const char *fmt, ...);

void modperl_trace_level_set(server_rec *s, const char *level);

#define modperl_log_warn(s,msg) \
    ap_log_error(APLOG_MARK, APLOG_WARNING, 0, s, "%s", msg)

#define modperl_log_error(s,msg) \
    ap_log_error(APLOG_MARK, APLOG_ERR, 0, s, "%s", msg)

#define modperl_log_notice(s,msg) \
    ap_log_error(APLOG_MARK, APLOG_NOTICE, 0, s, "%s", msg)

#define modperl_log_debug(s,msg) \
    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, s, "%s", msg)

#define modperl_log_reason(r,msg,file) \
    ap_log_error(APLOG_MARK, APLOG_ERR, 0, r->server, \
                 "access to %s failed for %s, reason: %s", \
                 file, \
                 get_remote_host(r->connection, \
                 r->per_dir_config, REMOTE_NAME), \
                 msg)

#endif /* MODPERL_LOG_H */
