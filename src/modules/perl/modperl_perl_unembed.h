#ifndef MODPERL_PERL_UNEMBED_H
#define MODPERL_PERL_UNEMBED_H

#ifdef PERL_CORE
#   ifndef croak
#      define croak Perl_croak_nocontext
#   endif
#endif

/* avoiding namespace collisions */

/* from XSUB.h */
/* mod_perl.c calls exit() in a few places */
#undef exit
/* modperl_tipool.c references abort() */
#undef abort
/* these three clash with apr bucket structure member names */
#undef link
#undef read
#undef free
/* modperl_perl.c */
#undef getpid

#undef list

#endif /* MODPERL_PERL_UNEMBED_H */

