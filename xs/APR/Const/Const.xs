#include "mod_perl.h"
#include "modperl_const.h"

MODULE = APR::Const    PACKAGE = APR::Const

PROTOTYPES: disable        

BOOT:
    newXS("APR::Const::compile", XS_modperl_const_compile, __FILE__);
