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

char *modperl_mgv_name_from_sv(pTHX_ apr_pool_t *p, SV *sv)
{
    char *name = NULL;
    GV *gv;

    if (SvROK(sv)) {
        sv = SvRV(sv);
    }

    switch (SvTYPE(sv)) {
      case SVt_PV:
        name = SvPVX(sv);
        break;
      case SVt_PVCV:
        if (CvANON((CV*)sv)) {
            Perl_croak(aTHX_ "anonymous handlers not (yet) supported");
        }
        gv = CvGV((CV*)sv);
        name = apr_pstrcat(p, HvNAME(GvSTASH(gv)), "::", GvNAME(gv), NULL);
        break;
    };

    return name;
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
                modperl_mgv_compile(aTHX_ p, HvNAME(GvSTASH(CvGV(cv))));
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

    if (modperl_require_module(aTHX_ package)) {
        MP_TRACE_h(MP_FUNC, "reloaded %s for server %s\n",
                   package, modperl_server_desc(s, p));
        return TRUE;
    }

    return FALSE;
}
#endif

/* precompute the hash(es) for handler names */
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

        if (MpHandlerPARSED(handler)) {
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
            MP_TRACE_h(MP_FUNC, "%s already resolved in server %s\n",
                       handler->name, modperl_server_desc(s, p));
        }
        else {
            if (MpSrvAUTOLOAD(scfg)) {
                MpHandlerAUTOLOAD_On(handler);
            }

            modperl_mgv_resolve(aTHX_ handler, p, handler->name);
        }
    }
}

static int modperl_hash_handlers_dir(apr_pool_t *p, server_rec *s,
                                     void *cfg, char *d, void *data)
{
#ifdef USE_ITHREADS
    MP_dSCFG(s);
    MP_dSCFG_dTHX;
#endif
    int i;
    modperl_config_dir_t *dir_cfg = (modperl_config_dir_t *)cfg;

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
