#include "mod_perl.h"
#include "modperl_const.h"

MODULE = Apache::Const    PACKAGE = Apache::Const

PROTOTYPES: disable

BOOT:
    MP_newModPerlConstXS("Apache");
