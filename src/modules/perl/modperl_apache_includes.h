#ifndef MODPERL_APACHE_INCLUDES_H
#define MODPERL_APACHE_INCLUDES_H

/* header files for Apache */

#ifndef CORE_PRIVATE
#define CORE_PRIVATE
#endif

#ifdef WIN32
#   include <winsock2.h>
#   include <malloc.h>
#   include <win32.h>
#   include <win32iop.h>
#   undef errno
#   undef read
#   include <fcntl.h>
#   include "EXTERN.h"
#   include "perl.h"
#   undef list

#   ifdef uid_t
#      define apache_uid_t uid_t
#      undef uid_t
#   endif
#   define uid_t apache_uid_t

#   ifdef gid_t
#      define apache_gid_t gid_t
#      undef gid_t
#   endif
#   define gid_t apache_gid_t
#endif /* WIN32 */

#include "ap_mmn.h"
#include "httpd.h"
#include "http_config.h"
#include "http_log.h"
#include "http_protocol.h"
#include "http_main.h"
#include "http_request.h"
#include "http_connection.h"
#include "http_core.h"
#include "ap_mpm.h"

#include "apr_lock.h"
#include "apr_strings.h"
#include "apr_uri.h"
#include "apr_date.h"
#include "apr_buckets.h"
#include "util_filter.h"

#include "util_script.h"

#endif /* MODPERL_APACHE_INCLUDES_H */
