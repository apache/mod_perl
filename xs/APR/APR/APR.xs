#include "mod_perl.h"

#ifdef WIN32
/* XXX:
 * these dont resolve even though we link against
 * libapr.lib and libaprutil.lib
 * will figure out why later, no rush since
 * this module is only needed for use APR functions outside of httpd
 * /
#   define apr_initialize()
#   define apr_terminate()
#endif

MODULE = APR    PACKAGE = APR

BOOT:
    file = file; /* -Wall */
    apr_initialize();

void
END()

    CODE:
    apr_terminate();
