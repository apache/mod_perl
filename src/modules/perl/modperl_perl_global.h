#ifndef MODPERL_PERL_GLOBAL_H
#define MODPERL_PERL_GLOBAL_H

typedef struct {
    GV *gv;
    AV *tmpav;
    AV *origav;
} modperl_perl_global_gvav_t;

typedef struct {
    GV *gv;
    HV *tmphv;
    HV *orighv;
} modperl_perl_global_gvhv_t;

typedef struct {
    GV *gv;
    char flags;
} modperl_perl_global_gvio_t;

typedef struct {
    SV **sv;
    char pv[256]; /* XXX: only need enough for $/ at the moment */
    I32 cur;
} modperl_perl_global_svpv_t;

typedef struct {
    modperl_perl_global_gvhv_t env;
    modperl_perl_global_gvav_t inc;
    modperl_perl_global_gvio_t defout;
    modperl_perl_global_svpv_t rs;
} modperl_perl_globals_t;

void modperl_perl_global_save(pTHX_ modperl_perl_globals_t *globals);

void modperl_perl_global_restore(pTHX_ modperl_perl_globals_t *globals);

#endif
