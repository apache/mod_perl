#include "mod_perl.h"
#include "modperl_const.h"

MODULE = ModPerl::Const    PACKAGE = ModPerl::Const

PROTOTYPES: disable

BOOT:
#XXX:
#currently used just for {APR,Apache}/Const.{so,dll} to lookup
#XS_modperl_const_compile
#linking is fun.
newXS("ModPerl::Const::compile", XS_modperl_const_compile, __FILE__);

