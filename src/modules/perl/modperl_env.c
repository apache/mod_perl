#include "mod_perl.h"
#include "util_script.h"

#define EnvMgObj SvMAGIC((SV*)GvHV(PL_envgv))->mg_ptr

static MP_INLINE
void mp_env_hv_store(pTHX_ HV *hv, apr_table_entry_t *elt)
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

static void mp_env_request_populate(pTHX_ request_rec *r)
{
    HV *hv = GvHV(PL_envgv);
    int i;
    U32 mg_flags;
    apr_array_header_t *array = apr_table_elts(r->subprocess_env);
    apr_table_entry_t *elts = (apr_table_entry_t *)array->elts;

    modperl_env_untie(mg_flags);

    for (i = 0; i < array->nelts; i++) {
	if (!elts[i].key || !elts[i].val) {
            continue;
        }
        mp_env_hv_store(aTHX_ hv, &elts[i]);
    }    

    modperl_env_tie(mg_flags);
}

static int mp_env_request_set(pTHX_ SV *sv, MAGIC *mg)
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
static int mp_env_request_get(pTHX_ SV *sv, MAGIC *mg)
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

void modperl_env_request_tie(pTHX_ request_rec *r)
{
    ap_add_common_vars(r);
    ap_add_cgi_vars(r);

    /* XXX: should be options #ifdef MP_PERL_HV_GMAGICAL_AWARE */
    mp_env_request_populate(aTHX_ r);

    EnvMgObj = (char *)r;

    PL_vtbl_envelem.svt_set = MEMBER_TO_FPTR(mp_env_request_set);
#ifdef MP_PERL_HV_GMAGICAL_AWARE
    SvGMAGICAL_on((SV*)GvHV(PL_envgv));
    PL_vtbl_envelem.svt_get = MEMBER_TO_FPTR(mp_env_request_get);
#endif
}

void modperl_env_request_untie(pTHX_ request_rec *r)
{
    PL_vtbl_envelem.svt_set = MEMBER_TO_FPTR(Perl_magic_setenv);
#ifdef MP_PERL_HV_GMAGICAL_AWARE
    SvGMAGICAL_off((SV*)GvHV(PL_envgv));
    PL_vtbl_envelem.svt_get = 0;
#endif
}
