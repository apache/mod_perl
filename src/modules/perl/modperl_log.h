#ifndef MODPERL_LOG_H
#define MODPERL_LOG_H

#ifdef MP_TRACE
/* XXX: not every cc supports this
 * sort out later
 */
#   define MP_FUNC __FUNCTION__
#else
#   define MP_FUNC "MP_FUNC"
#endif

#include "modperl_trace.h"

#ifdef _PTHREAD_H
#define modperl_thread_self() pthread_self()
#else
#define modperl_thread_self() 0
#endif

#define MP_TIDF \
(unsigned long)modperl_thread_self()

void modperl_trace(char *func, const char *fmt, ...);

void modperl_trace_level_set(const char *level);

#define modperl_log_warn(s,msg) \
    ap_log_error(APLOG_MARK, APLOG_WARNING|APLOG_NOERRNO, 0, s, "%s", msg)

#define modperl_log_error(s,msg) \
    ap_log_error(APLOG_MARK, APLOG_ERR|APLOG_NOERRNO, 0, s, "%s", msg)

#define modperl_log_notice(s,msg) \
    ap_log_error(APLOG_MARK, APLOG_NOERRNO|APLOG_NOTICE, 0, s, "%s", msg)

#define modperl_log_debug(s,msg) \
    ap_log_error(APLOG_MARK, APLOG_NOERRNO|APLOG_DEBUG, 0, s, "%s", msg)

#define modperl_log_reason(r,msg,file) \
    ap_log_error(APLOG_MARK, APLOG_ERR|APLOG_NOERRNO, 0, r->server, \
                 "access to %s failed for %s, reason: %s", \
                 file, \
                 get_remote_host(r->connection, \
                 r->per_dir_config, REMOTE_NAME), \
                 msg)

#endif /* MODPERL_LOG_H */
