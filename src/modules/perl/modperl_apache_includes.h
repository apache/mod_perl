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
#include "apr_general.h"
#include "apr_uuid.h"
#include "apr_env.h"

#include "util_filter.h"

#include "util_script.h"

#endif /* MODPERL_APACHE_INCLUDES_H */
