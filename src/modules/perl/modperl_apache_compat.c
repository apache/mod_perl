#include "mod_perl.h"

/* back compat adjustements for older Apache versions (2.0.36+) */

/* pre-APR_0_9_0 (APACHE_2_0_40) */
#if APR_MAJOR_VERSION == 0 && APR_MINOR_VERSION == 9 && \
    APR_PATCH_VERSION == 0 && defined(APR_IS_DEV_VERSION)

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

#endif /* pre-APR_0_9_0 (APACHE_2_0_40) */
