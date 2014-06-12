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

/*
 * mgv = ModPerl Glob Value || Mostly Glob Value
 * as close to GV as we can get without actually using a GV
 * need config structures to be free of Perl structures
 */

#define modperl_mgv_new_w_name(mgv, p, n, copy)         \
    mgv = modperl_mgv_new(p);                           \
    mgv->len = strlen(n);                               \
    mgv->name = (copy ? apr_pstrndup(p, n, mgv->len) : n)

#define modperl_mgv_new_name(mgv, p, n)         \
    modperl_mgv_new_w_name(mgv, p, n, 1)

#define modperl_mgv_new_namen(mgv, p, n)        \
    modperl_mgv_new_w_name(mgv, p, n, 0)

int modperl_mgv_equal(modperl_mgv_t *mgv1,
                      modperl_mgv_t *mgv2)
{
    for (; mgv1 && mgv2; mgv1=mgv1->next, mgv2=mgv2->next) {
        if (mgv1->hash != mgv2->hash) {
            return FALSE;
        }
        if (mgv1->len != mgv2->len) {
            return FALSE;
        }
        if (memNE(mgv1->name, mgv2->name, mgv1->len)) {
            return FALSE;
        }
    }

    return TRUE;
}

modperl_mgv_t *modperl_mgv_new(apr_pool_t *p)
{
    return (modperl_mgv_t *)apr_pcalloc(p, sizeof(modperl_mgv_t));
}

#define modperl_mgv_get_next(mgv)               \
    if (mgv->name) {                            \
        mgv->next = modperl_mgv_new(p);         \
        mgv = mgv->next;                        \
    }

#define modperl_mgv_hash(mgv)                   \
    PERL_HASH(mgv->hash, mgv->name, mgv->len)
 /* MP_TRACE_h(MP_FUNC, "%s...hash=%ld", mgv->name, mgv->hash) */

modperl_mgv_t *modperl_mgv_compile(pTHX_ apr_pool_t *p,
                                   register const char *name)
{
    register const char *namend;
    I32 len;
    modperl_mgv_t *symbol = modperl_mgv_new(p);
    modperl_mgv_t *mgv = symbol;

    /* @mgv = split '::', $name */
    for (namend = name; *namend; namend++) {
        if (*namend == ':' && namend[1] == ':') {
            if ((len = (namend - name)) > 0) {
                modperl_mgv_get_next(mgv);
                mgv->name = apr_palloc(p, len+3);
                Copy(name, mgv->name, len, char);
                mgv->name[len++] = ':';
                mgv->name[len++] = ':';
                mgv->name[len] = '\0';
                mgv->len = len;
                modperl_mgv_hash(mgv);
            }
            name = namend + 2;
        }
    }

    modperl_mgv_get_next(mgv);

    mgv->len = namend - name;
    mgv->name = apr_pstrndup(p, name, mgv->len);
    modperl_mgv_hash(mgv);

    return symbol;
}

void modperl_mgv_append(pTHX_ apr_pool_t *p, modperl_mgv_t *symbol,
                        const char *name)
{
    modperl_mgv_t *mgv = symbol;

    while (mgv->next) {
        mgv = mgv->next;
    }

    mgv->name = apr_pstrcat(p, mgv->name, "::", NULL);
    mgv->len += 2;
    modperl_mgv_hash(mgv);

    mgv->next = modperl_mgv_compile(aTHX_ p, name);
}

/* faster replacement for gv_fetchpv() */
GV *modperl_mgv_lookup(pTHX_ modperl_mgv_t *symbol)
{
    HV *stash = PL_defstash;
    modperl_mgv_t *mgv;

    if (!symbol->hash) {
        /* special case for MyClass->handler */
        return (GV*)sv_2mortal(newSVpvn(symbol->name, symbol->len));
    }

    for (mgv = symbol; mgv; mgv = mgv->next) {
        HE *he = hv_fetch_he(stash, mgv->name, mgv->len, mgv->hash);
        if (he) {
            if (mgv->next) {
                stash = GvHV((GV *)HeVAL(he));
            }
            else {
                return (GV *)HeVAL(he);
            }
        }
        else {
            return (GV *)NULL;
        }
    }

    return (GV *)NULL;
}

#ifdef USE_ITHREADS
MP_INLINE GV *modperl_mgv_lookup_autoload(pTHX_ modperl_mgv_t *symbol,
                                          server_rec *s, apr_pool_t *p)
{
    MP_dSCFG(s);
    GV *gv = modperl_mgv_lookup(aTHX_ symbol);

    if (gv || !MpSrvPARENT(scfg)) {
        return gv;
    }

    /*
     * this VirtualHost has its own parent interpreter
     * must require the module again with this server's THX
     */
    modperl_mgv_require_module(aTHX_ symbol, s, p);

    return modperl_mgv_lookup(aTHX_ symbol);
}
#else
MP_INLINE GV *modperl_mgv_lookup_autoload(pTHX_ modperl_mgv_t *symbol,
                                          server_rec *s, apr_pool_t *p)
{
    return modperl_mgv_lookup(aTHX_ symbol);
}
#endif

/* currently used for complex filters attributes parsing */
/* XXX: may want to generalize it for any handlers */
#define MODPERL_MGV_DEEP_RESOLVE(handler, p)                   \
    if (handler->attrs & MP_FILTER_HAS_INIT_HANDLER) {         \
        modperl_filter_resolve_init_handler(aTHX_ handler, p); \
    }

int modperl_mgv_resolve(pTHX_ modperl_handler_t *handler,
                        apr_pool_t *p, const char *name, int logfailure)
{
    CV *cv;
    GV *gv;
    HV *stash = (HV *)NULL;
    char *handler_name = "handler";
    char *tmp;

    if (MpHandlerANON(handler)) {
        /* already resolved anonymous handler */
        return 1;
    }

    if (strnEQ(name, "sub ", 4)) {
        SV *sv;
        CV *cv;
        MpHandlerPARSED_On(handler);
        MpHandlerANON_On(handler);

        ENTER;SAVETMPS;
        sv = eval_pv(name, TRUE);
        if (!(SvROK(sv) && (cv = (CV*)SvRV(sv)) && (CvFLAGS(cv) & CVf_ANON))) {

            Perl_croak(aTHX_ "expected anonymous sub, got '%s'\n", name);
        }

#ifdef USE_ITHREADS
        handler->cv      = NULL;
        handler->name    = NULL;
        handler->mgv_obj = modperl_handler_anon_next(aTHX_ p);
        modperl_handler_anon_add(aTHX_ handler->mgv_obj, cv);
        MP_TRACE_h(MP_FUNC, "[%s] new anon handler",
                   modperl_pid_tid(p));
#else
        SvREFCNT_inc(cv);
        handler->cv      = cv;
        handler->name    = NULL;
        MP_TRACE_h(MP_FUNC, "[%s] new cached-cv anon handler",
                   modperl_pid_tid(p));
#endif

        FREETMPS;LEAVE;

        return 1;
    }

    if ((tmp = strstr((char *)name, "->"))) {
        int package_len = strlen(name) - strlen(tmp);
        char *package = apr_pstrndup(p, name, package_len);

        name = package;
        handler_name = &tmp[2];

        MpHandlerMETHOD_On(handler);

        if (*package == '$') {
            GV *gv;
            SV *obj;

            handler->mgv_obj = modperl_mgv_compile(aTHX_ p, package + 1);
            gv = modperl_mgv_lookup(aTHX_ handler->mgv_obj);
            obj = gv ? GvSV(gv) : (SV *)NULL;

            if (SvTRUE(obj)) {
                if (SvROK(obj) && sv_isobject(obj)) {
                    stash = SvSTASH(SvRV(obj));
                    MpHandlerOBJECT_On(handler);
                    MP_TRACE_h(MP_FUNC, "handler object %s isa %s",
                               package, HvNAME(stash));
                }
                else {
                    MP_TRACE_h(MP_FUNC, "%s is not an object, pv=%s",
                               package, SvPV_nolen(obj));
                    return 0;
                }
            }
            else {
                MP_TRACE_h(MP_FUNC, "failed to thaw %s", package);
                return 0;
            }
        }

        if (!stash) {
            if ((stash = gv_stashpvn(package, package_len, FALSE))) {
                MP_TRACE_h(MP_FUNC, "handler method %s isa %s",
                           name, HvNAME(stash));
            }
        }
    }
    else {
        if ((cv = get_cv(name, FALSE))) {
            handler->attrs = *modperl_code_attrs(aTHX_ cv);
            handler->mgv_cv =
                modperl_mgv_compile(aTHX_ p, HvNAME(GvSTASH(CvGV(cv))));
            modperl_mgv_append(aTHX_ p, handler->mgv_cv, GvNAME(CvGV(cv)));
            MpHandlerPARSED_On(handler);
            MODPERL_MGV_DEEP_RESOLVE(handler, p);
            return 1;
        }
    }

    if (!stash && MpHandlerAUTOLOAD(handler)) {
        if (!modperl_perl_module_loaded(aTHX_ name)) { /* not in %INC */
            MP_TRACE_h(MP_FUNC,
                       "package %s not in %INC, attempting to load it",
                       name);

            if (modperl_require_module(aTHX_ name, logfailure)) {
                MP_TRACE_h(MP_FUNC, "loaded %s package", name);
            }
            else {
                if (logfailure) {
                    /* the caller doesn't handle the error checking */
                    Perl_croak(aTHX_ "failed to load %s package\n", name);
                }
                else {
                    /* the caller handles the error checking */
                    MP_TRACE_h(MP_FUNC, "failed to load %s package", name);
                    return 0;
                }
            }
        }
        else {
            MP_TRACE_h(MP_FUNC, "package %s seems to be loaded", name);
        }
    }

    /* try to lookup the stash only after loading the module, to avoid
     * the case where a stash is autovivified by a user before the
     * module was loaded, preventing from loading the module
     */
    if (!(stash || (stash = gv_stashpv(name, FALSE)))) {
        MP_TRACE_h(MP_FUNC, "%s's stash is not found", name);
        return 0;
    }

    if ((gv = gv_fetchmethod(stash, handler_name)) && (cv = GvCV(gv))) {
        if (CvFLAGS(cv) & CVf_METHOD) { /* sub foo : method {}; */
            MpHandlerMETHOD_On(handler);
        }

        if (!stash) {
            return 0;
        }


        if (MpHandlerMETHOD(handler) && !handler->mgv_obj) {
            char *name = HvNAME(stash);
            if (!name) {
                name = "";
            }
            modperl_mgv_new_name(handler->mgv_obj, p, name);
        }

        handler->attrs = *modperl_code_attrs(aTHX_ cv);
        /* note: this is the real function after @ISA lookup */
        handler->mgv_cv = modperl_mgv_compile(aTHX_ p, HvNAME(GvSTASH(gv)));
        modperl_mgv_append(aTHX_ p, handler->mgv_cv, handler_name);

        MpHandlerPARSED_On(handler);
        MP_TRACE_h(MP_FUNC, "[%s] found `%s' in class `%s' as a %s",
                   modperl_pid_tid(p),
                   handler_name, HvNAME(stash),
                   MpHandlerMETHOD(handler) ? "method" : "function");
        MODPERL_MGV_DEEP_RESOLVE(handler, p);
        return 1;
    }

    /* at least modperl_hash_handlers needs to verify that an
     * autoloaded-marked handler needs to be loaded, since it doesn't
     * check success failure, and handlers marked to be autoloaded are
     * the same as PerlModule and the failure should be fatal */
    if (MpHandlerAUTOLOAD(handler)) {
        Perl_croak(aTHX_ "failed to resolve handler %s\n", name);
    }

#ifdef MP_TRACE
    /* complain only if the class was actually loaded/created */
    if (stash) {
        MP_TRACE_h(MP_FUNC, "`%s' not found in class `%s'",
                   handler_name, name);
    }
#endif

    return 0;
}

modperl_mgv_t *modperl_mgv_last(modperl_mgv_t *symbol)
{
    while (symbol->next) {
        symbol = symbol->next;
    }

    return symbol;
}

char *modperl_mgv_last_name(modperl_mgv_t *symbol)
{
    symbol = modperl_mgv_last(symbol);
    return symbol->name;
}

char *modperl_mgv_as_string(pTHX_ modperl_mgv_t *symbol,
                            apr_pool_t *p, int package)
{
    char *string, *ptr;
    modperl_mgv_t *mgv;
    int len = 0;

    for (mgv = symbol; (package ? mgv->next : mgv); mgv = mgv->next) {
        len += mgv->len;
    }

    ptr = string = apr_palloc(p, len+1);

    for (mgv = symbol; (package ? mgv->next : mgv); mgv = mgv->next) {
        Copy(mgv->name, ptr, mgv->len, char);
        ptr += mgv->len;
    }

    if (package) {
        *(ptr-2) = '\0'; /* trim trailing :: */
    }
    else {
        *ptr = '\0';
    }

    return string;
}

#ifdef USE_ITHREADS
int modperl_mgv_require_module(pTHX_ modperl_mgv_t *symbol,
                               server_rec *s, apr_pool_t *p)
{
    char *package =
        modperl_mgv_as_string(aTHX_ symbol, p, 1);

    if (modperl_require_module(aTHX_ package, TRUE)) {
        MP_TRACE_h(MP_FUNC, "reloaded %s for server %s",
                   package, modperl_server_desc(s, p));
        return TRUE;
    }

    return FALSE;
}
#endif

/* precompute the hash(es) for handler names, preload handlers
 * configured to be autoloaded */
static void modperl_hash_handlers(pTHX_ apr_pool_t *p, server_rec *s,
                                  MpAV *entry, void *data)
{
    MP_dSCFG(s);
    int i;
    modperl_handler_t **handlers;

    if (!entry) {
        return;
    }

    handlers = (modperl_handler_t **)entry->elts;

    for (i=0; i < entry->nelts; i++) {
        modperl_handler_t *handler = handlers[i];

        if (MpHandlerFAKE(handler)) {
            /* do nothing with fake handlers */
        }
        else if (MpHandlerPARSED(handler)) {
#ifdef USE_ITHREADS
            if ((MpSrvPARENT(scfg) && MpSrvAUTOLOAD(scfg))
                && !modperl_mgv_lookup(aTHX_ handler->mgv_cv)) {
                /*
                 * this VirtualHost has its own parent interpreter
                 * must require the module again with this server's THX
                 */
                modperl_mgv_require_module(aTHX_ handler->mgv_cv,
                                           s, p);
            }
#endif
            MP_TRACE_h(MP_FUNC, "%s already resolved in server %s",
                       modperl_handler_name(handler),
                       modperl_server_desc(s, p));
        }
        else {
            if (MpSrvAUTOLOAD(scfg)) {
                MpHandlerAUTOLOAD_On(handler);
            }

            modperl_mgv_resolve(aTHX_ handler, p, handler->name, TRUE);
        }
    }
}

static int modperl_hash_handlers_dir(apr_pool_t *p, server_rec *s,
                                     void *cfg, char *d, void *data)
{
    int i;
    modperl_config_dir_t *dir_cfg = (modperl_config_dir_t *)cfg;
#ifdef USE_ITHREADS
    MP_dSCFG(s);
    MP_dSCFG_dTHX;
#endif

    if (!dir_cfg) {
        return 1;
    }

    for (i=0; i < MP_HANDLER_NUM_PER_DIR; i++) {
        modperl_hash_handlers(aTHX_ p, s, dir_cfg->handlers_per_dir[i], data);
    }

    return 1;
}

static int modperl_hash_handlers_srv(apr_pool_t *p, server_rec *s,
                                     void *cfg, void *data)
{
    int i;
    modperl_config_srv_t *scfg = (modperl_config_srv_t *)cfg;
    MP_dSCFG_dTHX;

    for (i=0; i < MP_HANDLER_NUM_PER_SRV; i++) {
        modperl_hash_handlers(aTHX_ p, s,
                              scfg->handlers_per_srv[i], data);
    }

    for (i=0; i < MP_HANDLER_NUM_PROCESS; i++) {
        modperl_hash_handlers(aTHX_ p, s,
                              scfg->handlers_process[i], data);
    }

    for (i=0; i < MP_HANDLER_NUM_CONNECTION; i++) {
        modperl_hash_handlers(aTHX_ p, s,
                              scfg->handlers_connection[i], data);
    }

    for (i=0; i < MP_HANDLER_NUM_FILES; i++) {
        modperl_hash_handlers(aTHX_ p, s,
                              scfg->handlers_files[i], data);
    }

    return 1;
}

void modperl_mgv_hash_handlers(apr_pool_t *p, server_rec *s)
{
    ap_pcw_walk_config(p, s, &perl_module, NULL,
                       modperl_hash_handlers_dir,
                       modperl_hash_handlers_srv);
}
