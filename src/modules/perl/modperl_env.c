#include "mod_perl.h"

#define EnvMgObj SvMAGIC((SV*)ENVHV)->mg_ptr
#define EnvMgLen SvMAGIC((SV*)ENVHV)->mg_len

static MP_INLINE
void modperl_env_hv_store(pTHX_ HV *hv, apr_table_entry_t *elt)
{
    I32 klen = strlen(elt->key);
    SV **svp = hv_fetch(hv, elt->key, klen, FALSE);

    if (svp) {
        sv_setpv(*svp, elt->val);
    }
    else {
        SV *sv = newSVpv(elt->val, 0);
        hv_store(hv, elt->key, klen, sv, FALSE);
        svp = &sv;
    }

    SvTAINTED_on(*svp);
}

typedef struct {
    const char *key;
    I32 klen;
    const char *val;
    I32 vlen;
    U32 hash;
} modperl_env_ent_t;

#define MP_ENV_ENT(k,v) \
{ k, MP_SSTRLEN(k), v, MP_SSTRLEN(v), 0 }

static modperl_env_ent_t MP_env_const_vars[] = {
#ifdef MP_COMPAT_1X
    MP_ENV_ENT("GATEWAY_INTERFACE", "CGI-Perl/1.1"),
#endif
    MP_ENV_ENT("MOD_PERL", MP_VERSION_STRING),
    { NULL }
};

void modperl_env_hash_keys(void)
{
    modperl_env_ent_t *ent = MP_env_const_vars;

    while (ent->key) {
        PERL_HASH(ent->hash, ent->key, ent->klen);
        ent++;
    }
}

void modperl_env_clear(pTHX)
{
    HV *hv = ENVHV;
    U32 mg_flags;

    modperl_env_untie(mg_flags);

    hv_clear(hv);

    modperl_env_tie(mg_flags);
}

void modperl_env_configure_server(pTHX_ apr_pool_t *p, server_rec *s)
{
    /* XXX: propagate scfg->SetEnv to environ */
}

#define overlay_subprocess_env(r, tab) \
    r->subprocess_env = apr_table_overlay(r->pool, \
                                          r->subprocess_env, \
                                          tab)

void modperl_env_configure_request(request_rec *r)
{
    MP_dDCFG;
    MP_dSCFG(r->server);

    if (!apr_is_empty_table(dcfg->SetEnv)) {
        overlay_subprocess_env(r, dcfg->SetEnv);
    }

    if (!apr_is_empty_table(scfg->PassEnv)) {
        overlay_subprocess_env(r, scfg->PassEnv);
    }
}

void modperl_env_default_populate(pTHX)
{
    modperl_env_ent_t *ent = MP_env_const_vars;
    HV *hv = ENVHV;
    U32 mg_flags;

    modperl_env_untie(mg_flags);

    while (ent->key) {
        hv_store(hv, ent->key, ent->klen,
                 newSVpvn(ent->val, ent->vlen), ent->hash);
        ent++;
    }

    modperl_env_tie(mg_flags);
}

void modperl_env_request_populate(pTHX_ request_rec *r)
{
    MP_dRCFG;
    HV *hv = ENVHV;
    U32 mg_flags;
    int i;
    const apr_array_header_t *array;
    apr_table_entry_t *elts;

    if (MpReqSETUP_ENV(rcfg)) {
        return;
    }

    MP_TRACE_g(MP_FUNC, "populating environment for %s\n", r->uri);

    /* XXX: might want to always do this regardless of PerlOptions -SetupEnv */
    modperl_env_configure_request(r);

    ap_add_common_vars(r);
    ap_add_cgi_vars(r);

    modperl_env_untie(mg_flags);

    array = apr_table_elts(r->subprocess_env);
    elts  = (apr_table_entry_t *)array->elts;

    for (i = 0; i < array->nelts; i++) {
	if (!elts[i].key || !elts[i].val) {
            continue;
        }
        modperl_env_hv_store(aTHX_ hv, &elts[i]);
    }    

    modperl_env_tie(mg_flags);

#ifdef MP_COMPAT_1X
    modperl_env_default_populate(aTHX); /* reset GATEWAY_INTERFACE */
#endif

    MpReqSETUP_ENV_On(rcfg);
}

void modperl_env_request_tie(pTHX_ request_rec *r)
{
    EnvMgObj = (char *)r;
    EnvMgLen = -1;

#ifdef MP_PERL_HV_GMAGICAL_AWARE
    SvGMAGICAL_on((SV*)ENVHV);
#endif
}

void modperl_env_request_untie(pTHX_ request_rec *r)
{
    EnvMgObj = NULL;

#ifdef MP_PERL_HV_GMAGICAL_AWARE
    SvGMAGICAL_off((SV*)ENVHV);
#endif
}

/* to store the original virtual tables
 * these are global, not per-interpreter
 */
static MGVTBL MP_PERL_vtbl_env;
static MGVTBL MP_PERL_vtbl_envelem;

#define MP_PL_vtbl_call(name, meth) \
    MP_PERL_vtbl_##name.svt_##meth(aTHX_ sv, mg)

#define MP_dENV_KEY \
    STRLEN klen; \
    const char *key = (const char *)MgPV(mg,klen)

#define MP_dENV_VAL \
    STRLEN vlen; \
    const char *val = (const char *)SvPV(sv,vlen)

/*
 * XXX: what we do here might change:
 *      - make it optional for %ENV to be tied to r->subprocess_env
 *      - make it possible to modify environ
 *      - we could allow modification of environ if mpm isn't threaded
 *      - we could allow modification of environ if variable isn't a CGI
 *        variable (still could cause problems)
 */
/*
 * problems we are trying to solve:
 *      - environ is shared between threads
 *          + Perl does not serialize access to environ
 *          + even if it did, CGI variables cannot be shared between threads!
 * problems we create by trying to solve above problems:
 *      - a forked process will not inherit the current %ENV
 *      - C libraries might rely on environ, e.g. DBD::Oracle
 */
static int modperl_env_magic_set_all(pTHX_ SV *sv, MAGIC *mg)
{
    request_rec *r = (request_rec *)EnvMgObj;

    if (r) {
        if (PL_localizing) {
            /* local %ENV = (FOO => 'bar', BIZ => 'baz') */
            HE *entry;
            STRLEN n_a;

            hv_iterinit((HV*)sv);
            while ((entry = hv_iternext((HV*)sv))) {
                I32 keylen;
                apr_table_set(r->subprocess_env,
                              hv_iterkey(entry, &keylen),
                              SvPV(hv_iterval((HV*)sv, entry), n_a));
            }
        }
    }
    else {
        return MP_PL_vtbl_call(env, set);
    }

    return 0;
}

static int modperl_env_magic_clear_all(pTHX_ SV *sv, MAGIC *mg)
{
    request_rec *r = (request_rec *)EnvMgObj;

    if (r) {
        apr_table_clear(r->subprocess_env);
    }
    else {
        return MP_PL_vtbl_call(env, clear);
    }

    return 0;
}

static int modperl_env_magic_set(pTHX_ SV *sv, MAGIC *mg)
{
    request_rec *r = (request_rec *)EnvMgObj;

    if (r) {
        MP_dENV_KEY;
        MP_dENV_VAL;
        apr_table_set(r->subprocess_env, key, val);
    }
    else {
        return MP_PL_vtbl_call(envelem, set);
    }

    return 0;
}

static int modperl_env_magic_clear(pTHX_ SV *sv, MAGIC *mg)
{
    request_rec *r = (request_rec *)EnvMgObj;

    if (r) {
        MP_dENV_KEY;
        apr_table_unset(r->subprocess_env, key);
    }
    else {
        return MP_PL_vtbl_call(envelem, clear);
    }

    return 0;
}

#ifdef MP_PERL_HV_GMAGICAL_AWARE
static int modperl_env_magic_get(pTHX_ SV *sv, MAGIC *mg)
{
    request_rec *r = (request_rec *)EnvMgObj;

    if (r) {
        MP_dENV_KEY;
        const char *val;

        if ((val = apr_table_get(r->subprocess_env, key))) {
            sv_setpv(sv, val);
        }
        else {
            sv_setsv(sv, &PL_sv_undef);
        }
    }
    else {
        /* there is no svt_get in PL_vtbl_envelem */
    }

    return 0;
}
#endif

/* override %ENV virtual tables with our own */
static MGVTBL MP_vtbl_env = {
    0,
    MEMBER_TO_FPTR(modperl_env_magic_set_all),
    0,
    MEMBER_TO_FPTR(modperl_env_magic_clear_all),
    0
};

static MGVTBL MP_vtbl_envelem =	{
    0,
    MEMBER_TO_FPTR(modperl_env_magic_set),
    0,
    MEMBER_TO_FPTR(modperl_env_magic_clear),
    0
};

void modperl_env_init(void)
{
    /* save originals */
    StructCopy(&PL_vtbl_env, &MP_PERL_vtbl_env, MGVTBL);
    StructCopy(&PL_vtbl_envelem, &MP_PERL_vtbl_envelem, MGVTBL);

    /* replace with our versions */
    StructCopy(&MP_vtbl_env, &PL_vtbl_env, MGVTBL);
    StructCopy(&MP_vtbl_envelem, &PL_vtbl_envelem, MGVTBL);
}
