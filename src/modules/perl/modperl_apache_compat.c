#include "mod_perl.h"

/* back compat adjustements for older Apache versions */

/* pre-APR_0_9_0 (APACHE_2_0_40) */
#if APR_MAJOR_VERSION == 0 && APR_MINOR_VERSION == 9 && \
    APR_PATCH_VERSION == 0 && defined(APR_IS_DEV_VERSION)

/* added in APACHE_2_0_40/APR_0_9_0 */
apr_status_t apr_socket_timeout_get(apr_socket_t *sock, apr_interval_time_t *t)
{
    modperl_apr_func_not_implemented(apr_sockettimeout_get, 2.0.40, 0.9.0);
    return APR_ENOTIMPL;
}

apr_status_t apr_socket_timeout_set(apr_socket_t *sock, apr_interval_time_t t)
{
    modperl_apr_func_not_implemented(apr_socket_timeout_set, 2.0.40, 0.9.0);
    return APR_ENOTIMPL;
}

#endif /* pre-APR_0_9_0 (APACHE_2_0_40) */

/* pre-APR_0_9_5 (APACHE_2_0_47)
 * both 2.0.46 and 2.0.47 shipped with 0.9.4 -
 * we need the one that shipped with 2.0.47,
   which is major mmn 20020903, minor mmn 4 */
#if ! AP_MODULE_MAGIC_AT_LEAST(20020903,4)

/* added in APACHE_2_0_47/APR_0_9_4 */
void apr_table_compress(apr_table_t *t, unsigned flags)
{
    modperl_apr_func_not_implemented(apr_table_compress, 2.0.47, 0.9.4);
}

#endif /* pre-APR_0_9_5 (APACHE_2_0_47) */
