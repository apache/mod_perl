#include "mod_perl.h"

int modperl_callback(pTHX_ modperl_handler_t *handler, apr_pool_t *p,
                     request_rec *r, server_rec *s, AV *args)
{
    CV *cv=Nullcv;
    I32 flags = G_EVAL|G_SCALAR;
    dSP;
    int count, status;

    if ((status = modperl_handler_resolve(aTHX_ &handler, p, s)) != OK) {
        return status;
    }

    ENTER;SAVETMPS;
    PUSHMARK(SP);

    if (MpHandlerMETHOD(handler)) {
        GV *gv = modperl_mgv_lookup(aTHX_ handler->mgv_obj);
        XPUSHs(modperl_mgv_sv(gv));
    }

    if (args) {
        I32 items = AvFILLp(args) + 1;

        EXTEND(SP, items);
        Copy(AvARRAY(args), SP + 1, items, SV*);
        SP += items;
    }

    PUTBACK;

    if (MpHandlerANON(handler)) {
        SV *sv = eval_pv(handler->name, TRUE); /* XXX: cache */
        cv = (CV*)SvRV(sv);
    }
    else {
        GV *gv = modperl_mgv_lookup_autoload(aTHX_ handler->mgv_cv, s, p);
        if (gv) {
            cv = modperl_mgv_cv(gv);
        }
        else {
            char *name = modperl_mgv_as_string(aTHX_ handler->mgv_cv, p, 0);
            MP_TRACE_h(MP_FUNC, "lookup of %s failed\n", name);
        }
    }

    if (MpHandlerMETHOD(handler)) {
        flags |= G_METHOD;
    }

    count = call_sv((SV*)cv, flags);

    SPAGAIN;

    if (count != 1) {
        status = OK;
    }
    else {
        status = POPi;
        /* assume OK for non-http status codes and for 200 (HTTP_OK) */
        if (((status > 0) && (status < 100)) ||
            (status == 200) || (status > 600)) {
            status = OK;
        }
    }

    PUTBACK;
    FREETMPS;LEAVE;

    if (SvTRUE(ERRSV)) {
        MP_TRACE_h(MP_FUNC, "$@ = %s", SvPVX(ERRSV));
        status = HTTP_INTERNAL_SERVER_ERROR;
    }

    return status;
}

int modperl_callback_run_handlers(int idx, int type,
                                  request_rec *r, conn_rec *c, server_rec *s,
                                  apr_pool_t *pconf,
                                  apr_pool_t *plog,
                                  apr_pool_t *ptemp)
{
#ifdef USE_ITHREADS
    pTHX;
    modperl_interp_t *interp = NULL;
#endif
    MP_dSCFG(s);
    MP_dDCFG;
    MP_dRCFG;
    modperl_handler_t **handlers;
    apr_pool_t *p = NULL;
    MpAV *av, **avp;
    int i, status = OK;
    const char *desc = NULL;
    AV *av_args = Nullav;

    if (!MpSrvENABLE(scfg)) {
        MP_TRACE_h(MP_FUNC, "PerlOff for server %s\n",
                   s->server_hostname);
        return DECLINED;
    }

    if (r || c) {
        p = c ? c->pool : r->pool;
    }
    else {
        p = pconf;
    }

    avp = modperl_handler_lookup_handlers(dcfg, scfg, rcfg, p,
                                          type, idx, FALSE, &desc);

    if (!(avp && (av = *avp))) {
        MP_TRACE_h(MP_FUNC, "no %s handlers configured (%s)\n",
                   desc, r ? r->uri : "");
        return DECLINED;
    }

#ifdef USE_ITHREADS
    if (r && !c && modperl_interp_scope_connection(scfg)) {
        c = r->connection;
    }
    if (r || c) {
        interp = modperl_interp_select(r, c, s);
        aTHX = interp->perl;
    }
    else {
        /* Child{Init,Exit}, OpenLogs */
        aTHX = scfg->mip->parent->perl;
        PERL_SET_CONTEXT(aTHX);
    }
#endif

    switch (type) {
      case MP_HANDLER_TYPE_PER_DIR:
      case MP_HANDLER_TYPE_PER_SRV:
        modperl_handler_make_args(aTHX_ &av_args,
                                  "Apache::RequestRec", r, NULL);

        /* only happens once per-request */
        if (MpDirSETUP_ENV(dcfg)) {
            modperl_env_request_populate(aTHX_ r);
        }
        break;
      case MP_HANDLER_TYPE_CONNECTION:
        modperl_handler_make_args(aTHX_ &av_args,
                                  "Apache::Connection", c, NULL);
        break;
      case MP_HANDLER_TYPE_FILES:
        modperl_handler_make_args(aTHX_ &av_args,
                                  "Apache::Pool", pconf,
                                  "Apache::Pool", plog,
                                  "Apache::Pool", ptemp,
                                  "Apache::Server", s, NULL);
        break;
      case MP_HANDLER_TYPE_PROCESS:
        modperl_handler_make_args(aTHX_ &av_args,
                                  "Apache::Pool", pconf,
                                  "Apache::Server", s, NULL);
        break;
    };

    /* XXX: deal with {push,set}_handler of the phase we're currently in */
    MP_TRACE_h(MP_FUNC, "running %d %s handlers\n",
               av->nelts, desc);
    handlers = (modperl_handler_t **)av->elts;

    for (i=0; i<av->nelts; i++) {
        if ((status = modperl_callback(aTHX_ handlers[i], p, r, s, av_args)) != OK) {
            status = modperl_errsv(aTHX_ status, r, s);
        }

        MP_TRACE_h(MP_FUNC, "%s returned %d\n",
                   handlers[i]->name, status);
    }

    SvREFCNT_dec((SV*)av_args);

#ifdef USE_ITHREADS
    if (interp && MpInterpPUTBACK(interp)) {
        /* PerlInterpScope handler */
        modperl_interp_unselect(interp);
    }
#endif

    return status;
}

int modperl_callback_per_dir(int idx, request_rec *r)
{
    return modperl_callback_run_handlers(idx, MP_HANDLER_TYPE_PER_DIR,
                                         r, NULL, r->server,
                                         NULL, NULL, NULL);
}

int modperl_callback_per_srv(int idx, request_rec *r)
{
    return modperl_callback_run_handlers(idx, MP_HANDLER_TYPE_PER_SRV,
                                         r, NULL, r->server,
                                         NULL, NULL, NULL);
}

int modperl_callback_connection(int idx, conn_rec *c)
{
    return modperl_callback_run_handlers(idx, MP_HANDLER_TYPE_CONNECTION,
                                         NULL, c, c->base_server,
                                         NULL, NULL, NULL);
}

void modperl_callback_process(int idx, apr_pool_t *p, server_rec *s)
{
    modperl_callback_run_handlers(idx, MP_HANDLER_TYPE_PROCESS,
                                  NULL, NULL, s,
                                  p, NULL, NULL);
}

void modperl_callback_files(int idx,
                            apr_pool_t *pconf, apr_pool_t *plog,
                            apr_pool_t *ptemp, server_rec *s)
{
    modperl_callback_run_handlers(idx, MP_HANDLER_TYPE_FILES,
                                  NULL, NULL, s,
                                  pconf, plog, ptemp);
}
