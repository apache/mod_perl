#ifndef MODPERL_CONST_H
#define MODPERL_CONST_H

#include "modperl_constants.h"

int modperl_const_compile(pTHX_ const char *classname,
                          const char *arg,
                          const char *name);

XS(XS_modperl_const_compile);

#endif /* MODPERL_CONST_H */
