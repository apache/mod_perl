#include "mod_perl.h"

#define EnvMgObj SvMAGIC((SV*)ENVHV)->mg_ptr

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
    apr_array_header_t *array;
    apr_table_entry_t *elts;


    if (MpReqSETUP_ENV(rcfg)) {
        return;
    }

    MP_TRACE_g(MP_FUNC, "populating environment for %s\n", r->uri);

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

static int modperl_env_request_set(pTHX_ SV *sv, MAGIC *mg)
{
    const char *key, *val;
    STRLEN klen, vlen;
    request_rec *r = (request_rec *)EnvMgObj;

    key = (const char *)MgPV(mg,klen);
    val = (const char *)SvPV(sv,vlen);

    apr_table_set(r->subprocess_env, key, val);

    /*return magic_setenv(sv, mg);*/

    return 0;
}

#ifdef MP_PERL_HV_GMAGICAL_AWARE
static int modperl_env_request_get(pTHX_ SV *sv, MAGIC *mg)
{
    const char *key, *val;
    STRLEN klen;
    request_rec *r = (request_rec *)EnvMgObj;

    key = (const char *)MgPV(mg,klen);

    if ((val = apr_table_get(r->subprocess_env, key))) {
        sv_setpv(sv, val);
    }
    else {
        sv_setsv(sv, &PL_sv_undef);
    }

    return 0;
}
#endif

/*
 * XXX: PL_vtbl_* are global (not per-interpreter)
 * so this method of tie-ing is not thread-safe
 * overridding svt_get is only useful with 5.7.2+ and requires
 * a smarter lookup than the current modperl_env_request_get
 */
void modperl_env_request_tie(pTHX_ request_rec *r)
{
    EnvMgObj = (char *)r;

    PL_vtbl_envelem.svt_set = MEMBER_TO_FPTR(modperl_env_request_set);
#ifdef MP_PERL_HV_GMAGICAL_AWARE
    SvGMAGICAL_on((SV*)ENVHV);
    PL_vtbl_envelem.svt_get = MEMBER_TO_FPTR(modperl_env_request_get);
#endif
}

void modperl_env_request_untie(pTHX_ request_rec *r)
{
    PL_vtbl_envelem.svt_set = MEMBER_TO_FPTR(Perl_magic_setenv);
#ifdef MP_PERL_HV_GMAGICAL_AWARE
    SvGMAGICAL_off((SV*)ENVHV);
    PL_vtbl_envelem.svt_get = 0;
#endif
}
