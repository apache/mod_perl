#include "mod_perl.h"
#include "modperl_const.h"

MODULE = APR::Const    PACKAGE = APR::Const

PROTOTYPES: disable        

BOOT:
    MP_newModPerlConstXS("APR");

