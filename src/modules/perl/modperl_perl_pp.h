#ifndef MODPERL_PERL_PP_H
#define MODPERL_PERL_PP_H

#if defined(USE_ITHREADS) && defined(MP_PERL_5_6_x)
#   define MP_REFGEN_FIXUP
#endif

typedef enum {
#ifdef MP_REFGEN_FIXUP
    MP_OP_SREFGEN,
#endif
    MP_OP_max
} modperl_perl_opcode_e;

void modperl_perl_pp_set(modperl_perl_opcode_e idx);

void modperl_perl_pp_set_all(void);

void modperl_perl_pp_unset(modperl_perl_opcode_e idx);

void modperl_perl_pp_unset_all(void);

#endif /* MODPERL_PERL_PP_H */
