#include "mod_perl.h"

/*
 * mgv = ModPerl Glob Value || Mostly Glob Value
 * as close to GV as we can get without actually using a GV
 * need config structures to be free of Perl structures
 */

#define modperl_mgv_new_w_name(mgv, p, n, copy) \
mgv = modperl_mgv_new(p); \
mgv->len = strlen(n); \
mgv->name = (copy ? apr_pstrndup(p, n, mgv->len) : n)

#define modperl_mgv_new_name(mgv, p, n) \
modperl_mgv_new_w_name(mgv, p, n, 1)

#define modperl_mgv_new_namen(mgv, p, n) \
modperl_mgv_new_w_name(mgv, p, n, 0)

/*
 * similar to hv_fetch_ent, but takes string key and key len rather than SV
 * also skips magic and utf8 fu, since we are only dealing with symbol tables
 */
static HE *S_hv_fetch_he(pTHX_ HV *hv,
                         register char *key,
                         register I32 klen,
                         register U32 hash)
{
    register XPVHV *xhv;
    register HE *entry;

    xhv = (XPVHV *)SvANY(hv);
    entry = ((HE**)xhv->xhv_array)[hash & (I32) xhv->xhv_max];

    for (; entry; entry = HeNEXT(entry)) {
        if (HeHASH(entry) != hash)
            continue;
        if (HeKLEN(entry) != klen)
            continue;
        if (HeKEY(entry) != key && memNE(HeKEY(entry),key,klen))
            continue;
        return entry;
    }

    return 0;
}

#define hv_fetch_he(hv,k,l,h) S_hv_fetch_he(aTHX_ hv,k,l,h)

modperl_mgv_t *modperl_mgv_new(apr_pool_t *p)
{
    return (modperl_mgv_t *)apr_pcalloc(p, sizeof(modperl_mgv_t));
}

#define modperl_mgv_get_next(mgv) \
    if (mgv->name) { \
        mgv->next = modperl_mgv_new(p); \
        mgv = mgv->next; \
    }

#define modperl_mgv_hash(mgv) \
    PERL_HASH(mgv->hash, mgv->name, mgv->len)
 /* MP_TRACE_h(MP_FUNC, "%s...hash=%ld\n", mgv->name, mgv->hash) */

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
            return Nullgv;
        }
    }

    return Nullgv;
}

int modperl_mgv_resolve(pTHX_ modperl_handler_t *handler,
                        apr_pool_t *p, const char *name)
{
    CV *cv;
    GV *gv;
    HV *stash=Nullhv;
    char *handler_name = "handler";
    char *tmp;

    if (strnEQ(name, "sub ", 4)) {
        MP_TRACE_h(MP_FUNC, "handler is anonymous\n");
        MpHandlerANON_On(handler);
        MpHandlerPARSED_On(handler);
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
            obj = gv ? GvSV(gv) : Nullsv;

            if (SvTRUE(obj)) {
                if (SvROK(obj) && sv_isobject(obj)) {
                    stash = SvSTASH(SvRV(obj));
                    MpHandlerOBJECT_On(handler);
                    MP_TRACE_h(MP_FUNC, "handler object %s isa %s\n",
                               package, HvNAME(stash));
                }
                else {
                    MP_TRACE_h(MP_FUNC, "%s is not an object, pv=%s\n",
                               package, SvPV_nolen(obj));
                    return 0;
                }
            }
            else {
                MP_TRACE_h(MP_FUNC, "failed to thaw %s\n", package);
                return 0;
            }
        }

        if (!stash) {
            if ((stash = gv_stashpvn(package, package_len, FALSE))) {
                MP_TRACE_h(MP_FUNC, "handler method %s isa %s\n",
                           name, HvNAME(stash));
            }
        }

        MpHandlerPARSED_On(handler);
    }
    else {
        if ((cv = get_cv(name, FALSE))) {
            handler->mgv_cv =
                modperl_mgv_compile(aTHX, p, HvNAME(GvSTASH(CvGV(cv))));
            modperl_mgv_append(aTHX_ p, handler->mgv_cv, GvNAME(CvGV(cv)));
            MpHandlerPARSED_On(handler);
            return 1;
        }
    }

    if (!(stash || (stash = gv_stashpv(name, FALSE))) &&
        MpHandlerAUTOLOAD(handler)) {
        MP_TRACE_h(MP_FUNC,
                   "package %s not defined, attempting to load\n", name);

        if (modperl_require_module(aTHX_ name)) {
            MP_TRACE_h(MP_FUNC, "loaded %s package\n", name);
            if (!(stash = gv_stashpv(name, FALSE))) {
                MP_TRACE_h(MP_FUNC, "%s package still does not exist\n",
                           name);
                return 0;
            }
        }
        else {
            MP_TRACE_h(MP_FUNC, "failed to load %s package\n", name);
            return 0;
        }
    }

    if ((gv = gv_fetchmethod(stash, handler_name)) && (cv = GvCV(gv))) {
        if (CvFLAGS(cv) & CVf_METHOD) { /* sub foo : method {}; */
            MpHandlerMETHOD_On(handler);
            if (!handler->mgv_obj) {
                modperl_mgv_new_name(handler->mgv_obj, p, HvNAME(stash));
            }
        }

        /* note: this is the real function after @ISA lookup */
        handler->mgv_cv = modperl_mgv_compile(aTHX_ p, HvNAME(GvSTASH(gv)));
        modperl_mgv_append(aTHX_ p, handler->mgv_cv, handler_name);
  
        MpHandlerPARSED_On(handler);
        MP_TRACE_h(MP_FUNC, "found `%s' in class `%s' as a %s\n",
                   handler_name, HvNAME(stash),
                   MpHandlerMETHOD(handler) ? "method" : "function");
        return 1;
    }
    
    MP_TRACE_h(MP_FUNC, "`%s' not found in class `%s'\n",
               handler_name, name);

    return 0;
}

char *modperl_mgv_as_string(pTHX_ modperl_mgv_t *symbol,
                            apr_pool_t *p)
{
    char *string, *ptr;
    modperl_mgv_t *mgv;
    int len = 0;

    for (mgv = symbol; mgv; mgv = mgv->next) {
        len += mgv->len;
    }

    ptr = string = apr_palloc(p, len+1);

    for (mgv = symbol; mgv; mgv = mgv->next) {
        Copy(mgv->name, ptr, mgv->len, char);
        ptr += mgv->len;
    }

    *ptr = '\0';

    return string;
}

/* precompute the hash(es) for handler names */
static void modperl_hash_handlers(pTHX_ apr_pool_t *p, server_rec *s,
                                  MpAV *entry)
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

        if (MpHandlerPARSED(handler)) {
            MP_TRACE_h(MP_FUNC, "%s already resolved\n", handler->name);
        }
        else {
            if (MpSrvAUTOLOAD(scfg)) {
                MpHandlerAUTOLOAD_On(handler);
            }

            modperl_mgv_resolve(aTHX_ handler, p, handler->name);
        }
    }
}

static int modperl_dw_hash_handlers(apr_pool_t *p, server_rec *s,
                                    void *cfg, char *d, void *data)
{
    MP_dSCFG(s);
    MP_dSCFG_dTHX;
    int i;
    modperl_dir_config_t *dir_cfg = (modperl_dir_config_t *)cfg;

    if (!dir_cfg) {
        return 1;
    }

    for (i=0; i < MP_PER_DIR_NUM_HANDLERS; i++) {
        modperl_hash_handlers(aTHX_ p, s, dir_cfg->handlers[i]);
    }

    return 1;
}

static int modperl_sw_hash_handlers(apr_pool_t *p, server_rec *s,
                                    void *cfg, void *data)
{
    int i;
    modperl_srv_config_t *scfg = (modperl_srv_config_t *)cfg;
    MP_dSCFG_dTHX;

    for (i=0; i < MP_PER_SRV_NUM_HANDLERS; i++) {
        modperl_hash_handlers(aTHX_ p, s,
                              scfg->handlers[i]);
    }

    for (i=0; i < MP_PROCESS_NUM_HANDLERS; i++) {
        modperl_hash_handlers(aTHX_ p, s,
                              scfg->process_cfg->handlers[i]);
    }

    for (i=0; i < MP_CONNECTION_NUM_HANDLERS; i++) {
        modperl_hash_handlers(aTHX_ p, s,
                              scfg->connection_cfg->handlers[i]);
    }

    for (i=0; i < MP_FILES_NUM_HANDLERS; i++) {
        modperl_hash_handlers(aTHX_ p, s,
                              scfg->files_cfg->handlers[i]);
    }

    return 1;
}

void modperl_mgv_hash_handlers(apr_pool_t *p, server_rec *s)
{
    ap_pcw_walk_config(p, s, &perl_module, NULL,
                       modperl_dw_hash_handlers,
                       modperl_sw_hash_handlers);
}
