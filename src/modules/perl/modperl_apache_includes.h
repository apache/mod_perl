#ifndef MODPERL_APACHE_INCLUDES_H
#define MODPERL_APACHE_INCLUDES_H

/* header files for Apache */

#define CORE_PRIVATE
#include "ap_mmn.h"
#include "httpd.h"
#include "http_config.h"
#include "http_log.h"
#include "http_protocol.h"
#include "http_main.h"
#include "http_request.h"
#include "http_connection.h"
#include "http_core.h"

#include "apr_lock.h"
#include "apr_strings.h"

#include "ap_buckets.h"
#include "util_filter.h"

#endif /* MODPERL_APACHE_INCLUDES_H */
