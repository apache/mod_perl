#include "mod_perl.h"

static void require_module(pTHX_ const char *pv)
{
    SV* sv;
    dSP;
    PUSHSTACKi(PERLSI_REQUIRE);
    PUTBACK;
    sv = sv_newmortal();
    sv_setpv(sv, "require ");
    sv_catpv(sv, pv);
    eval_sv(sv, G_DISCARD);
    SPAGAIN;
    POPSTACK;
}

modperl_handler_t *modperl_handler_new(apr_pool_t *p, void *h, int type)
{
    modperl_handler_t *handler = 
        (modperl_handler_t *)apr_pcalloc(p, sizeof(*handler));

    switch (type) {
      case MP_HANDLER_TYPE_SV:
        handler->cv = SvREFCNT_inc((SV*)h);
        MpHandlerPARSED_On(handler);
        break;
      case MP_HANDLER_TYPE_CHAR:
        handler->name = (char *)h;
        MP_TRACE_h(MP_FUNC, "new handler %s\n", handler->name);
        break;
    };

    apr_register_cleanup(p, (void*)handler,
                        modperl_handler_cleanup, apr_null_cleanup);

    return handler;
}

apr_status_t modperl_handler_cleanup(void *data)
{
    modperl_handler_t *handler = (modperl_handler_t *)data;
    modperl_handler_unparse(handler);
    return APR_SUCCESS;
}

void modperl_handler_cache_cv(pTHX_ modperl_handler_t *handler, CV *cv)
{
    if (1) {
        /* XXX: figure out how to invalidate cache
         * e.g. if subroutine is redefined
         */
        handler->cv = SvREFCNT_inc((SV*)cv);
        /* handler->cvgen = MP_sub_generation; */;
    }
    else {
        handler->cv = newSVpvf("%s::%s",
                               HvNAME(GvSTASH(CvGV(cv))),
                               GvNAME(CvGV(cv)));
    }
    MP_TRACE_h(MP_FUNC, "caching %s::%s\n",
               HvNAME(GvSTASH(CvGV(cv))),
               GvNAME(CvGV(cv)));
}

int modperl_handler_lookup(pTHX_ modperl_handler_t *handler,
                           char *class, char *name)
{
    CV *cv;
    GV *gv;
    HV *stash = gv_stashpv(class, FALSE);

    if (!stash) {
        MP_TRACE_h(MP_FUNC, "class %s not defined, attempting to load\n",
                   class);
        require_module(aTHX_ class);
        if (SvTRUE(ERRSV)) {
            MP_TRACE_h(MP_FUNC, "failed to load %s class\n", class);
            return 0;
        }
        else {
            MP_TRACE_h(MP_FUNC, "loaded %s class\n", class);
            if (!(stash = gv_stashpv(class, FALSE))) {
                MP_TRACE_h(MP_FUNC, "%s package still does not exist\n",
                           class);
                return 0;
            }
        }
    }

    if ((gv = gv_fetchmethod(stash, name)) && (cv = GvCV(gv))) {
        if (CvFLAGS(cv) & CVf_METHOD) { /* sub foo : method {}; */
            MpHandlerMETHOD_On(handler);
            handler->obj = newSVpv(class, 0);
            handler->cv = newSVpv(name, 0);
        }
        else {
            modperl_handler_cache_cv(aTHX_ handler, cv);
        }

        MpHandlerPARSED_On(handler);
        MP_TRACE_h(MP_FUNC, "found `%s' in class `%s' as a %s\n",
                   name, HvNAME(stash),
                   MpHandlerMETHOD(handler) ? "method" : "function");

        return 1;
    }
    
    MP_TRACE_h(MP_FUNC, "`%s' not found in class `%s'\n",
               name, HvNAME(stash));

    return 0;
}

void modperl_handler_unparse(modperl_handler_t *handler)
{
    dTHXa(handler->perl);
    int was_parsed = handler->args || handler->cv || handler->obj;

    if (!MpHandlerPARSED(handler)) {
        if (was_parsed) {
            MP_TRACE_h(MP_FUNC, "handler %s was parsed, but not flagged\n",
                       handler->name);
        }
        else {
            MP_TRACE_h(MP_FUNC, "handler %s was never parsed\n", handler->name);
            return;
        }
    }

    MpHandlerFLAGS(handler) = 0;
    handler->cvgen = 0;

    if (handler->args) {
        av_clear(handler->args);
        SvREFCNT_dec((SV*)handler->args);
        handler->args = Nullav;
    }
    if (handler->cv) {
        SvREFCNT_dec(handler->cv);
        handler->cv = Nullsv;
    }
    if (handler->obj) {
        SvREFCNT_dec(handler->obj);
        handler->obj = Nullsv;
    }

    MP_TRACE_h(MP_FUNC, "%s unparsed\n", handler->name);
}

int modperl_handler_parse(pTHX_ modperl_handler_t *handler)
{
    char *name = handler->name;
    char *tmp;
    CV *cv;

#ifdef USE_ITHREADS
    handler->perl = aTHX;
#endif

    if (strnEQ(name, "sub ", 4)) {
        handler->cv = eval_pv(name, FALSE);
        MP_TRACE_h(MP_FUNC, "handler is anonymous\n");
        if (!SvTRUE(handler->cv) || SvTRUE(ERRSV)) {
            MP_TRACE_h(MP_FUNC, "eval failed: %s\n", SvPVX(ERRSV));
            handler->cv = Nullsv;
            return 0;
        }
        SvREFCNT_inc(handler->cv);
        MpHandlerANON_On(handler);
        MpHandlerPARSED_On(handler);
        return 1;
    }
    
    if ((tmp = strstr(name, "->"))) {
        char class[256]; /*XXX*/
        int class_len = strlen(name) - strlen(tmp);
        apr_cpystrn(class, name, class_len+1);

        MpHandlerMETHOD_On(handler);
        handler->cv = newSVpv(&tmp[2], 0);

        if (*class == '$') {
            SV *obj = eval_pv(class, FALSE);

            if (SvTRUE(obj)) {
                handler->obj = SvREFCNT_inc(obj);
                if (SvROK(obj) && sv_isobject(obj)) {
                    MpHandlerOBJECT_On(handler);
                    MP_TRACE_h(MP_FUNC, "handler object %s isa %s\n",
                               class, HvNAME(SvSTASH((SV*)SvRV(obj))));
                }
                else {
                    MP_TRACE_h(MP_FUNC, "%s is not an object, pv=%s\n",
                               class, SvPV_nolen(obj));
                }
            }
            else {
                MP_TRACE_h(MP_FUNC, "failed to thaw %s\n", class);
                return 0;
            }
        }

        if (!handler->obj) {
            handler->obj = newSVpv(class, class_len);
            MP_TRACE_h(MP_FUNC, "handler method %s isa %s\n",
                       SvPVX(handler->cv), class);
        }

        MpHandlerPARSED_On(handler);
        return 1;
    }

    if ((cv = get_cv(name, FALSE))) {
        modperl_handler_cache_cv(aTHX_ handler, cv);
        MpHandlerPARSED_On(handler);
        return 1;
    }

    if (modperl_handler_lookup(aTHX_ handler, name, "handler")) {
        return 1;
    }

    return 0;
}

int modperl_callback(pTHX_ modperl_handler_t *handler, apr_pool_t *p)
{
    dSP;
    int count, status;

#ifdef USE_ITHREADS
    if (p) {
        /* under ithreads, each handler needs to get_cv() from the
         * selected interpreter so the proper CvPADLIST is used
         * XXX: this should probably be reworked so threads can cache
         * parsed handlers
         */
        modperl_handler_t *new_handler = 
            modperl_handler_new(p, (void*)handler->name,
                                MP_HANDLER_TYPE_CHAR);
        handler = new_handler;
    }
#endif

    if (!MpHandlerPARSED(handler)) {
        if (!modperl_handler_parse(aTHX_ handler)) {
            MP_TRACE_h(MP_FUNC, "failed to parse handler `%s'\n",
                       handler->name);
            return HTTP_INTERNAL_SERVER_ERROR;
        }
    }

    ENTER;SAVETMPS;
    PUSHMARK(SP);

    if (MpHandlerMETHOD(handler)) {
        XPUSHs(handler->obj);
    }

    if (handler->args) {
        I32 i, len = AvFILL(handler->args);

        EXTEND(SP, len);
        for (i=0; i<=len; i++) {
            PUSHs(sv_2mortal(*av_fetch(handler->args, i, FALSE)));
        }
    }

    PUTBACK;

    if (MpHandlerMETHOD(handler)) {
        count = call_method(SvPVX(handler->cv), G_EVAL|G_SCALAR);
    }
    else {
        count = call_sv(handler->cv, G_EVAL|G_SCALAR);
    }

    SPAGAIN;

    if (count != 1) {
        status = OK;
    }
    else {
        status = POPi;
    }

    PUTBACK;
    FREETMPS;LEAVE;

    if (SvTRUE(ERRSV)) {
        MP_TRACE_h(MP_FUNC, "$@ = %s\n", SvPVX(ERRSV));
        status = HTTP_INTERNAL_SERVER_ERROR;
    }

    return status;
}

#define MP_HANDLER_TYPE_DIR 1
#define MP_HANDLER_TYPE_SRV 2
#define MP_HANDLER_TYPE_CONN 3
#define MP_HANDLER_TYPE_PROC 4
#define MP_HANDLER_TYPE_FILE 5

int modperl_run_handlers(int idx, request_rec *r, conn_rec *c,
                         server_rec *s, int type)
{
#ifdef USE_ITHREADS
    pTHX;
    modperl_interp_t *interp = NULL;
#endif
    MP_dSCFG(s);
    MP_dDCFG;
    modperl_handler_t **handlers;
    apr_pool_t *p = NULL;
    MpAV *av = NULL;
    int i, status = OK;
    const char *desc = NULL;

    if (!MpSrvENABLED(scfg)) {
        MP_TRACE_h(MP_FUNC, "PerlOff for server %s\n",
                   s->server_hostname);
        return DECLINED;
    }

    switch (type) {
      case MP_HANDLER_TYPE_DIR:
        av = dcfg->handlers[idx];
        MP_TRACE_a_do(desc = modperl_per_dir_handler_desc(idx));
        break;
      case MP_HANDLER_TYPE_SRV:
        av = scfg->handlers[idx];
        MP_TRACE_a_do(desc = modperl_per_srv_handler_desc(idx));
        break;
      case MP_HANDLER_TYPE_CONN:
        av = scfg->connection_cfg->handlers[idx];
        MP_TRACE_a_do(desc = modperl_connection_handler_desc(idx));
        break;
      case MP_HANDLER_TYPE_FILE:
        av = scfg->files_cfg->handlers[idx];
        MP_TRACE_a_do(desc = modperl_files_handler_desc(idx));
        break;
      case MP_HANDLER_TYPE_PROC:
        av = scfg->process_cfg->handlers[idx];
        MP_TRACE_a_do(desc = modperl_process_handler_desc(idx));
        break;
    };

    if (!av) {
        MP_TRACE_h(MP_FUNC, "no %s handlers configured (%s)\n",
                   desc, r ? r->uri : "");
        return DECLINED;
    }

#ifdef USE_ITHREADS
    if (r || c) {
        p = c ? c->pool : r->pool;
        interp = modperl_interp_select(r, c, s);
        aTHX = interp->perl;
    }
    else {
        /* Child{Init,Exit}, OpenLogs */
        aTHX = scfg->mip->parent->perl;
    }
    PERL_SET_CONTEXT(aTHX);
#endif

    MP_TRACE_h(MP_FUNC, "running %d %s handlers\n",
               av->nelts, desc);
    handlers = (modperl_handler_t **)av->elts;

    for (i=0; i<av->nelts; i++) {
        status = modperl_callback(aTHX_ handlers[i], p);
        MP_TRACE_h(MP_FUNC, "%s returned %d\n",
                   handlers[i]->name, status);
    }

#ifdef USE_ITHREADS
    if (interp && MpInterpPUTBACK_On(interp)) {
        /* XXX: might want to put interp back into available pool
         * rather than have it marked as in_use for the lifetime of
         * a request
         */
    }
#endif

    return status;
}

int modperl_per_dir_callback(int idx, request_rec *r)
{
    return modperl_run_handlers(idx, r, NULL, r->server, MP_HANDLER_TYPE_DIR);
}

int modperl_per_srv_callback(int idx, request_rec *r)
{
    return modperl_run_handlers(idx, r, NULL, r->server, MP_HANDLER_TYPE_SRV);
}

int modperl_connection_callback(int idx, conn_rec *c)
{
    return modperl_run_handlers(idx, NULL, c, c->base_server,
                                MP_HANDLER_TYPE_CONN);
}

void modperl_process_callback(int idx, apr_pool_t *p, server_rec *s)
{
    modperl_run_handlers(idx, NULL, NULL, s, MP_HANDLER_TYPE_PROC);
}

void modperl_files_callback(int idx,
                            apr_pool_t *pconf, apr_pool_t *plog,
                            apr_pool_t *ptemp, server_rec *s)
{
    modperl_run_handlers(idx, NULL, NULL, s, MP_HANDLER_TYPE_FILE);
}
