#include "mod_perl.h"

MODULE = APR    PACKAGE = APR

BOOT:
    file = file; /* -Wall */
    apr_initialize();

void
END()

    CODE:
    apr_terminate();
