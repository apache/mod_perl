#include "mod_perl.h"
#include "modperl_const.h"

MODULE = APR::Const    PACKAGE = APR::Const

BOOT:
    newXS("APR::Const::compile", XS_modperl_const_compile, file);
