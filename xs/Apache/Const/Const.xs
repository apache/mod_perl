#include "mod_perl.h"
#include "modperl_const.h"

MODULE = Apache::Const    PACKAGE = Apache::Const

BOOT:
    newXS("Apache::Const::compile", XS_modperl_const_compile, __FILE__);
