#include "mod_perl.h"

#ifdef MP_HAVE_APR_LIBS
#   define APR_initialize apr_initialize
#   define APR_terminate  apr_terminate
#else
#   define APR_initialize()
#   define APR_terminate()
#endif

#ifdef MP_HAVE_APR_LIBS

/* XXX: APR_initialize doesn't initialize apr_hook_global_pool, needed for
 * work outside httpd, so do it manually PR22605 */
#include "apr_hooks.h"
static void extra_apr_init(void)
{
    if (apr_hook_global_pool == NULL) {
        apr_pool_t *global_pool;
        apr_status_t rv = apr_pool_create(&global_pool, NULL);
        if (rv != APR_SUCCESS) {
            fprintf(stderr, "Fatal error: unable to create global pool "
                    "for use with by the scoreboard");
        }
        /* XXX: mutex locking? */
        apr_hook_global_pool = global_pool;
    }
}
#else
#   define extra_apr_init()
#endif

MODULE = APR    PACKAGE = APR

PROTOTYPES: disable

BOOT:
    file = file; /* -Wall */
    APR_initialize();
    extra_apr_init();

void
END()

    CODE:
    APR_terminate();
