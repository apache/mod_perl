#ifndef MODPERL_CONST_H
#define MODPERL_CONST_H

#include "modperl_constants.h"

int modperl_const_compile(pTHX_ const char *classname,
                          const char *arg,
                          const char *name);

XS(XS_modperl_const_compile);

#define MP_newModPerlConstXS(name) \
   newXS(name "::Const::compile", \
         CvXSUB(get_cv("ModPerl::Const::compile", TRUE)), \
         __FILE__)

#endif /* MODPERL_CONST_H */
