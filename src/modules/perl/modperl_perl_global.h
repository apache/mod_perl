#ifndef MODPERL_PERL_GLOBAL_H
#define MODPERL_PERL_GLOBAL_H

typedef struct {
    const char *name;
    const char *val;
    I32 len;
    U32 hash;
} modperl_modglobal_key_t;

typedef enum {
    MP_MODGLOBAL_END,
} modperl_modglobal_key_e;

typedef struct {
    AV **av;
    AV *origav;
    modperl_modglobal_key_e key;
} modperl_perl_global_avcv_t;

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
    modperl_perl_global_avcv_t end;
    modperl_perl_global_gvhv_t env;
    modperl_perl_global_gvav_t inc;
    modperl_perl_global_gvio_t defout;
    modperl_perl_global_svpv_t rs;
} modperl_perl_globals_t;

void modperl_perl_global_request_save(pTHX_ request_rec *r);

void modperl_perl_global_request_restore(pTHX_ request_rec *r);

void modperl_perl_global_avcv_call(pTHX_ modperl_modglobal_key_t *gkey,
                                   const char *package, I32 packlen);

void modperl_perl_global_avcv_clear(pTHX_ modperl_modglobal_key_t *gkey,
                                    const char *package, I32 packlen);

#endif
