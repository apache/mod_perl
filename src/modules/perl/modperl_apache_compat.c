#include "mod_perl.h"

/* back compat adjustements for older Apache versions
 * BACK_COMPAT_MARKER: make back compat issues easy to find :)
 */

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
