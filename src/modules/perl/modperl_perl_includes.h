#ifndef MODPERL_PERL_INCLUDES
#define MODPERL_PERL_INCLUDES

/* header files for Perl */

#ifndef PERL_NO_GET_CONTEXT
#   define PERL_NO_GET_CONTEXT
#endif

#define PERLIO_NOT_STDIO 0
#define PERL_CORE

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef PERL_CORE
#   ifndef croak
#      define croak Perl_croak_nocontext
#   endif
#endif

#undef dNOOP
#define dNOOP extern int __attribute__ ((unused)) Perl___notused

#endif /* MODPERL_PERL_INCLUDES */
