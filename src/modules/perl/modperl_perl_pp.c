#include "mod_perl.h"

static enum opcode MP_pp_map[] = {
#ifdef MP_REFGEN_FIXUP
    OP_SREFGEN,
#endif
    OP_REQUIRE
};

typedef OP * (*modperl_pp_t)(pTHX);

static modperl_pp_t MP_PERL_ppaddr[MP_OP_max];

#ifdef MP_REFGEN_FIXUP

/*
 * nasty workaround for bug fixed in bleedperl (11536 + 11553)
 * XXX: when 5.8.0 is released + stable, we will require 5.8.0
 * if ithreads are enabled.
 */

static OP *modperl_pp_srefgen(pTHX)
{
    dSP;
    OP *o;
    SV *sv = *SP;

    if (SvPADTMP(sv) && IS_PADGV(sv)) {
        /* prevent S_refto from making a copy of the GV,
         * tricking it to SvREFCNT_inc and point to this one instead.
         */
        SvPADTMP_off(sv);
    }
    else {
        sv = Nullsv;
    }

    /* o = Perl_pp_srefgen(aTHX) */
    o = MP_PERL_ppaddr[MP_OP_SREFGEN](aTHX);

    if (sv) {
        /* restore original flags */
        SvPADTMP_on(sv);
    }

    return o;
}

#endif /* MP_REFGEN_FIXUP */

static OP *modperl_pp_require(pTHX)
{
    /* nothing yet */
    return MP_PERL_ppaddr[MP_OP_REQUIRE](aTHX);
}

static modperl_pp_t MP_ppaddr[] = {
#ifdef MP_REFGEN_FIXUP
    MEMBER_TO_FPTR(modperl_pp_srefgen),
#endif
    MEMBER_TO_FPTR(modperl_pp_require)
};

void modperl_perl_pp_set(modperl_perl_opcode_e idx)
{
    int pl_idx = MP_pp_map[idx];

    /* save original */
    MP_PERL_ppaddr[idx] = PL_ppaddr[pl_idx];

    /* replace with our own */
    PL_ppaddr[pl_idx] = MP_ppaddr[idx];
}

void modperl_perl_pp_set_all(void)
{
    int i;

    for (i=0; i<MP_OP_max; i++) {
        modperl_perl_pp_set(i);
    }
}

void modperl_perl_pp_unset(modperl_perl_opcode_e idx)
{
    int pl_idx = MP_pp_map[idx];

    /* restore original */
    PL_ppaddr[pl_idx] = MP_PERL_ppaddr[idx];
}

void modperl_perl_pp_unset_all(void)
{
    int i;

    for (i=0; i<MP_OP_max; i++) {
        modperl_perl_pp_unset(i);
    }
}
