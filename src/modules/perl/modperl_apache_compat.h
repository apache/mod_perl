#ifndef MODPERL_APACHE_COMPAT_H
#define MODPERL_APACHE_COMPAT_H

/* back compat adjustements for older Apache versions (2.0.36+) */

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
apr_status_t apr_socket_timeout_get(apr_socket_t *sock, apr_interval_time_t *t);
apr_status_t apr_socket_timeout_set(apr_socket_t *sock, apr_interval_time_t t);

#endif /* pre-APR_0_9_0 (APACHE_2_0_40) */

#endif /* MODPERL_APACHE_COMPAT_H */
