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

#include "apr_lib.h"
#include "apr_strings.h"
#include "apr_uri.h"
#include "apr_date.h"
#include "apr_buckets.h"
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

#endif /* MODPERL_APACHE_INCLUDES_H */
