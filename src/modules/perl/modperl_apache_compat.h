#ifndef MODPERL_APACHE_COMPAT_H
#define MODPERL_APACHE_COMPAT_H

/* back compat adjustements for older Apache versions */

#if !APR_HAS_THREADS
typedef unsigned long apr_os_thread_t;
typedef void * apr_thread_mutex_t;
#endif

/* XXX: these backcompat macros can be deleted when we bump up the
 * minimal supported httpd version to 2.0.47 or higher
 * BACK_COMPAT_MARKER: make back compat issues easy to find :)
 */

/* pre-APR_0_9_5 (APACHE_2_0_47)
 * both 2.0.46 and 2.0.47 shipped with 0.9.4 -
 * we need the one that shipped with 2.0.47,
   which is major mmn 20020903, minor mmn 4 */
#if ! AP_MODULE_MAGIC_AT_LEAST(20020903,4)

/* added in APACHE_2_0_47/APR_0_9_4 */
void apr_table_compress(apr_table_t *t, unsigned flags);

#endif /* pre-APR_0_9_5 (APACHE_2_0_47) */

#define modperl_apr_func_not_implemented(func, httpd_ver, apr_ver) \
    { \
        dTHX; \
        Perl_croak(aTHX_ #func "() requires httpd/" #httpd_ver \
                               " and apr/" #apr_ver " or higher"); \
    }

#endif /* MODPERL_APACHE_COMPAT_H */
