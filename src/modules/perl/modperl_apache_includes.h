#ifndef MODPERL_APACHE_INCLUDES_H
#define MODPERL_APACHE_INCLUDES_H

/* header files for Apache */

#ifndef CORE_PRIVATE
#define CORE_PRIVATE
#endif

#include "ap_mmn.h"
#include "httpd.h"
#include "http_config.h"
#include "http_log.h"
#include "http_protocol.h"
#include "http_main.h"
#include "http_request.h"
#include "http_connection.h"
#include "http_core.h"
#include "http_vhost.h"
#include "ap_mpm.h"

#include "apr_version.h"
#ifndef APR_POLLIN
/*
 * apr_poll.h introduced around 2.0.40
 * APR_POLL* constants moved here around 2.0.44
 */
#include "apr_poll.h"
#endif
#include "apr_lib.h"
#include "apr_strings.h"
#include "apr_uri.h"
#include "apr_date.h"
#include "apr_buckets.h"
#include "apr_time.h"
#include "apr_network_io.h"

#include "util_filter.h"

#include "util_script.h"

#if !APR_HAS_THREADS
typedef unsigned long apr_os_thread_t;
typedef void * apr_thread_mutex_t;
#endif

/* XXX: these backcompat macros can be deleted when we bump up the
 * minimal supported httpd version to 2.0.40 or higher
 */
#ifndef apr_time_sec
#define apr_time_sec(time) ((apr_int64_t)((time) / APR_USEC_PER_SEC))
#endif
#ifndef apr_time_usec
#define apr_time_usec(time) ((apr_int32_t)((time) % APR_USEC_PER_SEC))
#endif
#ifndef apr_time_from_sec
#define apr_time_from_sec(sec) ((apr_time_t)(sec) * APR_USEC_PER_SEC)
#endif 


/* pre-APR_0_9_0 (APACHE_2_0_40) */
#if APR_MAJOR_VERSION == 0 && APR_MINOR_VERSION == 9 && \
    APR_PATCH_VERSION == 0 && defined(APR_IS_DEV_VERSION)

/* deprecated since APR_0_9_0 */
#define apr_socket_opt_get apr_getsocketopt
#define apr_socket_opt_set apr_setsocketopt

#define modperl_apr_func_not_implemented(func, ver) \
    { \
        dTHX; \
        Perl_croak(aTHX_ #func "() requires APR version " #ver " or higher"); \
    }

/* added in APACHE_2_0_40/APR_0_9_0 */
apr_status_t apr_socket_timeout_get(apr_socket_t *sock, apr_interval_time_t *t)
{
    modperl_apr_func_not_implemented(timeout_get, 0.9.0);
    return APR_ENOTIMPL;
}
apr_status_t apr_socket_timeout_set(apr_socket_t *sock, apr_interval_time_t t)
{
    modperl_apr_func_not_implemented(timeout_set, 0.9.0);
    return APR_ENOTIMPL;
}

#endif

#endif /* MODPERL_APACHE_INCLUDES_H */
