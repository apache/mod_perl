#ifndef MODPERL_PERL_INCLUDES_H
#define MODPERL_PERL_INCLUDES_H

/* header files for Perl */

#ifndef PERL_NO_GET_CONTEXT
#   define PERL_NO_GET_CONTEXT
#endif

#define PERLIO_NOT_STDIO 0

/*
 * sizeof(struct PerlInterpreter) changes #ifdef USE_LARGE_FILES
 * apache-2.0 cannot be compiled with lfs because of sendfile.h
 * the PERL_CORE optimization is a no-no in this case
 */
#if defined(USE_ITHREADS) && !defined(USE_LARGE_FILES)
#   define PERL_CORE
#endif

#ifdef MP_SOURCE_SCAN
/* XXX: C::Scan does not properly remove __attribute__ within
 * function prototypes; so we just rip them all out via cpp
 */
#   undef __attribute__
#   define __attribute__(arg)
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef PERL_CORE
#   ifndef croak
#      define croak Perl_croak_nocontext
#   endif
#endif

/* avoiding namespace collisions */

#ifdef list
#   undef list
#endif

/* avoiding -Wall warning */

#undef dNOOP
#define dNOOP extern int __attribute__ ((unused)) Perl___notused

#ifndef G_METHOD
#   define G_METHOD 64
#endif

#endif /* MODPERL_PERL_INCLUDES_H */
