/* Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "mod_perl.h"

#define EnvMgOK  ((SV*)ENVHV && SvMAGIC((SV*)ENVHV))
#define EnvMgObj (EnvMgOK ? SvMAGIC((SV*)ENVHV)->mg_ptr : NULL)
#define EnvMgLen (EnvMgOK ? SvMAGIC((SV*)ENVHV)->mg_len : 0)
#define EnvMgObjSet(val){ \
    if (EnvMgOK) SvMAGIC((SV*)ENVHV)->mg_ptr = (char *)val;}
#define EnvMgLenSet(val) {\
    if (EnvMgOK) SvMAGIC((SV*)ENVHV)->mg_len = val;}

/* XXX: move to utils? */
static unsigned long modperl_interp_address(pTHX)
{
#ifdef USE_ITHREADS
    return (unsigned long)aTHX;
#else
    return (unsigned long)0; /* just one interpreter */
#endif
}

#define MP_ENV_HV_STORE(hv, key, val) STMT_START {              \
        I32 klen = strlen(key);                                 \
        SV **svp = hv_fetch(hv, key, klen, FALSE);              \
                                                                \
        if (svp) {                                              \
            sv_setpv(*svp, val);                                \
        }                                                       \
        else {                                                  \
            SV *sv = newSVpv(val, 0);                           \
            (void)hv_store(hv, key, klen, sv, FALSE);           \
            modperl_envelem_tie(sv, key, klen);                 \
            svp = &sv;                                          \
        }                                                       \
        MP_TRACE_e(MP_FUNC, "$ENV{%s} = \"%s\";", key, val);    \
                                                                \
        SvTAINTED_on(*svp);                                     \
    } STMT_END

void modperl_env_hv_store(pTHX_ const char *key, const char *val)
{
    MP_ENV_HV_STORE(ENVHV, key, val);
}

static MP_INLINE
void modperl_env_hv_delete(pTHX_ HV *hv, char *key)
{
    I32 klen = strlen(key);
    if (hv_exists(hv, key, klen)) {
        (void)hv_delete(hv, key, strlen(key), G_DISCARD);
    }
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
    MP_ENV_ENT("MOD_PERL", MP_VERSION_STRING),
    MP_ENV_ENT("MOD_PERL_API_VERSION", MP_API_VERSION),
    { NULL }
};

void modperl_env_hash_keys(pTHX)
{
    modperl_env_ent_t *ent = MP_env_const_vars;

    while (ent->key) {
        PERL_HASH(ent->hash, ent->key, ent->klen);
        MP_TRACE_e(MP_FUNC, "[0x%lx] PERL_HASH: %s (len: %d)",
                   modperl_interp_address(aTHX), ent->key, ent->klen);
        ent++;
    }
}

void modperl_env_clear(pTHX)
{
    HV *hv = ENVHV;
    U32 mg_flags;

    modperl_env_untie(mg_flags);

    MP_TRACE_e(MP_FUNC, "[0x%lx] %%ENV = ();", modperl_interp_address(aTHX));

    hv_clear(hv);

    modperl_env_tie(mg_flags);
}

#define MP_ENV_HV_STORE_TABLE_ENTRY(hv, elt)    \
    MP_ENV_HV_STORE(hv, elt.key, elt.val);

static void modperl_env_table_populate(pTHX_ apr_table_t *table)
{
    HV *hv = ENVHV;
    U32 mg_flags;
    int i;
    const apr_array_header_t *array;
    apr_table_entry_t *elts;

    modperl_env_untie(mg_flags);

    array = apr_table_elts(table);
    elts  = (apr_table_entry_t *)array->elts;

    for (i = 0; i < array->nelts; i++) {
        if (!elts[i].key || !elts[i].val) {
            continue;
        }
        MP_ENV_HV_STORE_TABLE_ENTRY(hv, elts[i]);
    }

    modperl_env_tie(mg_flags);
}

static void modperl_env_table_unpopulate(pTHX_ apr_table_t *table)
{
    HV *hv = ENVHV;
    U32 mg_flags;
    int i;
    const apr_array_header_t *array;
    apr_table_entry_t *elts;

    modperl_env_untie(mg_flags);

    array = apr_table_elts(table);
    elts  = (apr_table_entry_t *)array->elts;

    for (i = 0; i < array->nelts; i++) {
        if (!elts[i].key) {
            continue;
        }
        modperl_env_hv_delete(aTHX_ hv, elts[i].key);
        MP_TRACE_e(MP_FUNC, "delete $ENV{%s};", elts[i].key);
    }

    modperl_env_tie(mg_flags);
}

/* see the comment in modperl_env_sync_env_hash2table */
static void modperl_env_sync_table(pTHX_ apr_table_t *table)
{
    int i;
    const apr_array_header_t *array;
    apr_table_entry_t *elts;
    HV *hv = ENVHV;
    SV **svp;

    array = apr_table_elts(table);
    elts  = (apr_table_entry_t *)array->elts;

    for (i = 0; i < array->nelts; i++) {
        if (!elts[i].key) {
            continue;
        }
        svp = hv_fetch(hv, elts[i].key, strlen(elts[i].key), FALSE);
        if (svp) {
            apr_table_set(table, elts[i].key, SvPV_nolen(*svp));
            MP_TRACE_e(MP_FUNC, "(Set|Pass)Env '%s' '%s'", elts[i].key,
                       SvPV_nolen(*svp));
        }
    }
    TAINT_NOT; /* SvPV_* causes the taint issue */
}

/* Make per-server PerlSetEnv and PerlPassEnv in sync with %ENV at
 * config time (if perl is running), by copying %ENV values to the
 * PerlSetEnv and PerlPassEnv tables (only for keys which are already
 * in those tables)
 */
void modperl_env_sync_srv_env_hash2table(pTHX_ apr_pool_t *p,
                                         modperl_config_srv_t *scfg)
{
    modperl_env_sync_table(aTHX_ scfg->SetEnv);
    modperl_env_sync_table(aTHX_ scfg->PassEnv);
}

void modperl_env_sync_dir_env_hash2table(pTHX_ apr_pool_t *p,
                                         modperl_config_dir_t *dcfg)
{
    modperl_env_sync_table(aTHX_ dcfg->SetEnv);
}

/* list of environment variables to pass by default */
static const char *MP_env_pass_defaults[] = {
    "PATH", "TZ", NULL
};

void modperl_env_configure_server(pTHX_ apr_pool_t *p, server_rec *s)
{
    MP_dSCFG(s);
    int i = 0;

    /* make per-server PerlSetEnv and PerlPassEnv entries visible
     * to %ENV at config time
     */

    for (i=0; MP_env_pass_defaults[i]; i++) {
        const char *key = MP_env_pass_defaults[i];
        char *val;

        if (apr_table_get(scfg->SetEnv, key) ||
            apr_table_get(scfg->PassEnv, key))
        {
            continue; /* already configured */
        }

        if ((val = getenv(key))) {
            apr_table_set(scfg->PassEnv, key, val);
        }
    }

    MP_TRACE_e(MP_FUNC, "\t[%s/0x%lx/%s]"
               "\n\t@ENV{keys scfg->SetEnv} = values scfg->SetEnv;",
               modperl_pid_tid(p), modperl_interp_address(aTHX),
               modperl_server_desc(s, p));
    modperl_env_table_populate(aTHX_ scfg->SetEnv);

    MP_TRACE_e(MP_FUNC, "\t[%s/0x%lx/%s]"
               "\n\t@ENV{keys scfg->PassEnv} = values scfg->PassEnv;",
               modperl_pid_tid(p), modperl_interp_address(aTHX),
               modperl_server_desc(s, p));
    modperl_env_table_populate(aTHX_ scfg->PassEnv);
}

#define overlay_subprocess_env(r, tab) \
    r->subprocess_env = apr_table_overlay(r->pool, \
                                          r->subprocess_env, \
                                          tab)

void modperl_env_configure_request_dir(pTHX_ request_rec *r)
{
    MP_dRCFG;
    MP_dDCFG;

    /* populate %ENV and r->subprocess_env with per-directory
     * PerlSetEnv entries.
     *
     * note that per-server PerlSetEnv entries, as well as
     * PerlPassEnv entries (which are only per-server), are added
     * to %ENV and r->subprocess_env via modperl_env_configure_request_srv
     */

    if (!apr_is_empty_table(dcfg->SetEnv)) {
        apr_table_t *setenv_copy;

        /* add per-directory PerlSetEnv entries to %ENV
         * collisions with per-server PerlSetEnv entries are
         * resolved via the nature of a Perl hash
         */
        MP_TRACE_e(MP_FUNC, "\t[%s/0x%lx/%s]"
                   "\n\t@ENV{keys dcfg->SetEnv} = values dcfg->SetEnv;",
                   modperl_pid_tid(r->pool), modperl_interp_address(aTHX),
                   modperl_server_desc(r->server, r->pool));
        modperl_env_table_populate(aTHX_ dcfg->SetEnv);

        /* make sure the entries are in the subprocess_env table as well.
         * we need to use apr_table_overlap (not apr_table_overlay) because
         * r->subprocess_env might have per-server PerlSetEnv entries in it
         * and using apr_table_overlay would generate duplicate entries.
         * in order to use apr_table_overlap, though, we need to copy the
         * the dcfg table so that pool requirements are satisfied */

        setenv_copy = apr_table_copy(r->pool, dcfg->SetEnv);
        apr_table_overlap(r->subprocess_env, setenv_copy, APR_OVERLAP_TABLES_SET);
    }

    MpReqPERL_SET_ENV_DIR_On(rcfg);
}

void modperl_env_configure_request_srv(pTHX_ request_rec *r)
{
    MP_dRCFG;
    MP_dSCFG(r->server);

    /* populate %ENV and r->subprocess_env with per-server PerlSetEnv
     * and PerlPassEnv entries.
     *
     * although both are setup in %ENV in modperl_request_configure_server
     * %ENV will be reset via modperl_env_request_unpopulate.
     */

    if (!apr_is_empty_table(scfg->SetEnv)) {
        MP_TRACE_e(MP_FUNC, "\t[%s/0x%lx/%s]"
                   "\n\t@ENV{keys scfg->SetEnv} = values scfg->SetEnv;",
                   modperl_pid_tid(r->pool), modperl_interp_address(aTHX),
                   modperl_server_desc(r->server, r->pool));
        modperl_env_table_populate(aTHX_ scfg->SetEnv);

        overlay_subprocess_env(r, scfg->SetEnv);
    }

    if (!apr_is_empty_table(scfg->PassEnv)) {
        MP_TRACE_e(MP_FUNC, "\t[%s/0x%lx/%s]"
                   "\n\t@ENV{keys scfg->PassEnv} = values scfg->PassEnv;",
                   modperl_pid_tid(r->pool), modperl_interp_address(aTHX),
                   modperl_server_desc(r->server, r->pool));
        modperl_env_table_populate(aTHX_ scfg->PassEnv);

        overlay_subprocess_env(r, scfg->PassEnv);
    }

    MpReqPERL_SET_ENV_SRV_On(rcfg);
}

void modperl_env_default_populate(pTHX)
{
    modperl_env_ent_t *ent = MP_env_const_vars;
    HV *hv = ENVHV;
    U32 mg_flags;

    modperl_env_untie(mg_flags);

    while (ent->key) {
        SV *sv = newSVpvn(ent->val, ent->vlen);
        (void)hv_store(hv, ent->key, ent->klen,
                       sv, ent->hash);
        MP_TRACE_e(MP_FUNC, "$ENV{%s} = \"%s\";", ent->key, ent->val);
        modperl_envelem_tie(sv, ent->key, ent->klen);
        ent++;
    }

    modperl_env_tie(mg_flags);
}

void modperl_env_request_populate(pTHX_ request_rec *r)
{
    MP_dRCFG;

    /* this is called under the following conditions
     *   - if PerlOptions +SetupEnv
     *   - if $r->subprocess_env() is called in a void context with no args
     *
     * normally, %ENV is only populated once per request (if at all) -
     * just prior to content generation if +SetupEnv.
     *
     * however, in the $r->subprocess_env() case it will be called
     * more than once - once for each void call, and once again just
     * prior to content generation.  while costly, the multiple
     * passes are required, otherwise void calls would prohibit later
     * phases from populating %ENV with new subprocess_env table entries
     */

    MP_TRACE_e(MP_FUNC, "\t[%s/0x%lx/%s%s]"
               "\n\t@ENV{keys r->subprocess_env} = values r->subprocess_env;",
               modperl_pid_tid(r->pool), modperl_interp_address(aTHX),
               modperl_server_desc(r->server, r->pool), r->uri);

    /* we can eliminate some of the cost by only doing CGI variables once
     * per-request no matter how many times $r->subprocess_env() is called
     */
    if (! MpReqSETUP_ENV(rcfg)) {

        ap_add_common_vars(r);
        ap_add_cgi_vars(r);

    }

    modperl_env_table_populate(aTHX_ r->subprocess_env);

    /* don't set up CGI variables again this request.
     * this also triggers modperl_env_request_unpopulate, which
     * resets %ENV between requests - see modperl_config_request_cleanup
     */
    MpReqSETUP_ENV_On(rcfg);
}

void modperl_env_request_unpopulate(pTHX_ request_rec *r)
{
    MP_dRCFG;

    /* unset only once */
    if (!MpReqSETUP_ENV(rcfg)) {
        return;
    }

    MP_TRACE_e(MP_FUNC,
               "\n\t[%s/0x%lx/%s%s]\n\tdelete @ENV{keys r->subprocess_env};",
               modperl_pid_tid(r->pool), modperl_interp_address(aTHX),
               modperl_server_desc(r->server, r->pool), r->uri);
    modperl_env_table_unpopulate(aTHX_ r->subprocess_env);

    MpReqSETUP_ENV_Off(rcfg);
}

void modperl_env_request_tie(pTHX_ request_rec *r)
{
    EnvMgObjSet(r);
    EnvMgLenSet(-1);

#ifdef MP_PERL_HV_GMAGICAL_AWARE
    MP_TRACE_e(MP_FUNC, "[%s/0x%lx] tie %%ENV, $r\t (%s%s)",
               modperl_pid_tid(r->pool), modperl_interp_address(aTHX),
               modperl_server_desc(r->server, r->pool), r->uri);
    SvGMAGICAL_on((SV*)ENVHV);
#endif
}

void modperl_env_request_untie(pTHX_ request_rec *r)
{
    EnvMgObjSet(NULL);

#ifdef MP_PERL_HV_GMAGICAL_AWARE
    MP_TRACE_e(MP_FUNC, "[%s/0x%lx] untie %%ENV; # from r\t (%s%s)",
               modperl_pid_tid(r->pool), modperl_interp_address(aTHX),
               modperl_server_desc(r->server, r->pool), r->uri);
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
                MP_TRACE_e(MP_FUNC, "[%s/0x%lx] localizing: %s => %s",
                           modperl_pid_tid(r->pool),
                           modperl_interp_address(aTHX),
                           hv_iterkey(entry, &keylen),
                           SvPV(hv_iterval((HV*)sv, entry), n_a));
            }
        }
    }
    else {
#ifdef MP_TRACE
        HE *entry;
        STRLEN n_a;

        MP_TRACE_e(MP_FUNC,
                   "\n\t[%lu/0x%lx] populating %%ENV:",
                   (unsigned long)getpid(), modperl_interp_address(aTHX));

        hv_iterinit((HV*)sv);

        while ((entry = hv_iternext((HV*)sv))) {
                I32 keylen;
                MP_TRACE_e(MP_FUNC, "$ENV{%s} = \"%s\";",
                           modperl_pid_tid(r->pool),
                           modperl_interp_address(aTHX),
                           hv_iterkey(entry, &keylen),
                           SvPV(hv_iterval((HV*)sv, entry), n_a));
            }
#endif
        return MP_PL_vtbl_call(env, set);
    }

    return 0;
}

static int modperl_env_magic_clear_all(pTHX_ SV *sv, MAGIC *mg)
{
    request_rec *r = (request_rec *)EnvMgObj;

    if (r) {
        apr_table_clear(r->subprocess_env);
        MP_TRACE_e(MP_FUNC,
                   "[%s/0x%lx] clearing all magic off r->subprocess_env",
                   modperl_pid_tid(r->pool), modperl_interp_address(aTHX));
    }
    else {
        MP_TRACE_e(MP_FUNC,
                   "[%s/0x%lx] %%ENV = ();",
                   modperl_pid_tid(r->pool), modperl_interp_address(aTHX));
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
        MP_TRACE_e(MP_FUNC, "[%s/0x%lx] r->subprocess_env set: %s => %s",
                   modperl_pid_tid(r->pool),
                   modperl_interp_address(aTHX), key, val);
    }
    else {
#ifdef MP_TRACE
        MP_dENV_KEY;
        MP_dENV_VAL;
        MP_TRACE_e(MP_FUNC,
                   "[%lu/0x%lx] $ENV{%s} = \"%s\";",
                   (unsigned long)getpid(),
                   modperl_interp_address(aTHX), key, val);
#endif
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
        MP_TRACE_e(MP_FUNC, "[%s/0x%lx] r->subprocess_env unset: %s",
                   modperl_pid_tid(r->pool),
                   modperl_interp_address(aTHX), key);
    }
    else {
#ifdef MP_TRACE
        MP_dENV_KEY;
        MP_TRACE_e(MP_FUNC, "[%lu/0x%lx] delete $ENV{%s};",
                   (unsigned long)getpid(),
                   modperl_interp_address(aTHX), key);
#endif
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
            MP_TRACE_e(MP_FUNC,
                       "[%s/0x%lx] r->subprocess_env get: %s => %s",
                       modperl_pid_tid(r->pool),
                       modperl_interp_address(aTHX), key, val);
        }
        else {
            sv_setsv(sv, &PL_sv_undef);
            MP_TRACE_e(MP_FUNC,
                       "[%s/0x%lx] r->subprocess_env get: %s => undef",
                       modperl_pid_tid(r->pool),
                       modperl_interp_address(aTHX), key);
        }
    }
    else {
        /* there is no svt_get in PL_vtbl_envelem */
#ifdef MP_TRACE
        MP_dENV_KEY;
        MP_TRACE_e(MP_FUNC,
                   "[%lu/0x%lx] there is no svt_get in PL_vtbl_envelem: %s",
                   (unsigned long)getpid(),
                   modperl_interp_address(aTHX), key);
#endif
    }

    return 0;
}
#endif

/* override %ENV virtual tables with our own */
static MGVTBL MP_vtbl_env = {
    0,
    modperl_env_magic_set_all,
    0,
    modperl_env_magic_clear_all,
    0
};

static MGVTBL MP_vtbl_envelem = {
    0,
    modperl_env_magic_set,
    0,
    modperl_env_magic_clear,
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

void modperl_env_unload(void)
{
    /* restore originals */
    StructCopy(&MP_PERL_vtbl_env, &PL_vtbl_env, MGVTBL);
    StructCopy(&MP_PERL_vtbl_envelem, &PL_vtbl_envelem, MGVTBL);
}
