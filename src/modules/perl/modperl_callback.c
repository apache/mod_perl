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

modperl_handler_t *modperl_handler_new(ap_pool_t *p, void *h, int type)
{
    modperl_handler_t *handler = 
        (modperl_handler_t *)ap_pcalloc(p, sizeof(*handler));

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

    ap_register_cleanup(p, (void*)handler,
                        modperl_handler_cleanup, ap_null_cleanup);

    return handler;
}

ap_status_t modperl_handler_cleanup(void *data)
{
    modperl_handler_t *handler = (modperl_handler_t *)data;
    dTHXa(handler->perl);
    modperl_handler_unparse(aTHX_ handler);
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

void modperl_handler_unparse(pTHX_ modperl_handler_t *handler)
{
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
        ap_cpystrn(class, name, class_len+1);

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

int modperl_callback(pTHX_ modperl_handler_t *handler)
{
    dSP;
    int count, status;

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

int modperl_run_handlers(int idx, request_rec *r, server_rec *s, int type)
{
    pTHX;
    MP_dSCFG(s);
    modperl_handler_t **handlers;
    MpAV *av;
    int i, status;
    const char *desc;

    if (type == MP_HANDLER_TYPE_DIR) {
        MP_dDCFG;
        av = dcfg->handlers[idx];
        MP_TRACE_a_do(desc = modperl_per_dir_handler_desc(idx));
    }
    else {
        av = scfg->handlers[idx];
        MP_TRACE_a_do(desc = modperl_per_srv_handler_desc(idx));
    }

    if (!av) {
        MP_TRACE_h(MP_FUNC, "no %s handlers configured (%s)\n",
                   desc, r ? r->uri : "");
        return DECLINED;
    }

    if (r) {
        MP_dRCFG;
        if (!rcfg) {
            rcfg = modperl_request_config_new(r);
            ap_set_module_config(r->request_config, &perl_module, rcfg);
        }
#ifdef USE_ITHREADS
        aTHX = rcfg->interp->perl;
#endif
    }
#ifdef USE_ITHREADS
    else if (s) {
        /* Child{Init,Exit} */
        aTHX = scfg->mip->parent->perl;
    }
#endif

    MP_TRACE_h(MP_FUNC, "running %d %s handlers\n",
               av->nelts, desc);
    handlers = (modperl_handler_t **)av->elts;

    for (i=0; i<av->nelts; i++) {
        status = modperl_callback(aTHX_ handlers[i]);
        MP_TRACE_h(MP_FUNC, "%s returned %d\n",
                   handlers[i]->name, status);
    }

    return status;
}

int modperl_per_dir_callback(int idx, request_rec *r)
{
    return modperl_run_handlers(idx, r, r->server, MP_HANDLER_TYPE_DIR);
}

int modperl_per_srv_callback(int idx, request_rec *r)
{
    return modperl_run_handlers(idx, r, r->server, MP_HANDLER_TYPE_SRV);
}

int modperl_connection_callback(int idx, conn_rec *c)
{
    return DECLINED;
}

void modperl_process_callback(int idx, ap_pool_t *p, server_rec *s)
{
}

void modperl_files_callback(int idx,
                            ap_pool_t *pconf, ap_pool_t *plog,
                            ap_pool_t *ptemp, server_rec *s)
{
}
