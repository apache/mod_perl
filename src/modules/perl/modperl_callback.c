#include "mod_perl.h"

modperl_handler_t *modperl_handler_new(apr_pool_t *p, const char *name)
{
    modperl_handler_t *handler = 
        (modperl_handler_t *)apr_pcalloc(p, sizeof(*handler));

    handler->name = name;
    MP_TRACE_h(MP_FUNC, "new handler %s\n", handler->name);

    return handler;
}

modperl_handler_t *modperl_handler_dup(apr_pool_t *p,
                                       modperl_handler_t *h)
{
    MP_TRACE_h(MP_FUNC, "dup handler %s\n", h->name);
    return modperl_handler_new(p, h->name);
}

void modperl_handler_make_args(pTHX_ AV **avp, ...)
{
    va_list args;

    if (!*avp) {
        *avp = newAV(); /* XXX: cache an intialized AV* per-request */
    }

    va_start(args, avp);

    for (;;) {
        char *classname = va_arg(args, char *);
        void *ptr;
        SV *sv;
            
        if (classname == NULL) {
            break;
        }

        ptr = va_arg(args, void *);

        switch (*classname) {
          case 'I':
            if (strEQ(classname, "IV")) {
                sv = ptr ? newSViv((IV)ptr) : &PL_sv_undef;
                break;
            }
          case 'P':
            if (strEQ(classname, "PV")) {
                sv = ptr ? newSVpv((char *)ptr, 0) : &PL_sv_undef;
                break;
            }
          default:
            sv = modperl_ptr2obj(aTHX_ classname, ptr);
            break;
        }

        av_push(*avp, sv);
    }

    va_end(args);
}

int modperl_callback(pTHX_ modperl_handler_t *handler, apr_pool_t *p,
                     AV *args)
{
    CV *cv=Nullcv;
    I32 flags = G_EVAL|G_SCALAR;
    dSP;
    int count, status;

#ifdef USE_ITHREADS
    if (p && !MpHandlerPARSED(handler)) {
        /*
         * cannot update the handler structure at request time without
         * locking, so just copy it
         */
        handler = modperl_handler_dup(p, handler);
    }
#endif

    MP_TRACE_h_do(MpHandler_dump_flags(handler, handler->name));

    if (!MpHandlerPARSED(handler)) {
        MpHandlerAUTOLOAD_On(handler);
        if (!modperl_mgv_resolve(aTHX_ handler, p, handler->name)) {
            MP_TRACE_h(MP_FUNC, "failed to resolve handler `%s'\n",
                       handler->name);
            return HTTP_INTERNAL_SERVER_ERROR;
        }
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
        GV *gv = modperl_mgv_lookup(aTHX_ handler->mgv_cv);
        if (gv) {
            cv = modperl_mgv_cv(gv);
        }
        else {
            char *name = modperl_mgv_as_string(aTHX_ handler->mgv_cv, p);
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
    }

    PUTBACK;
    FREETMPS;LEAVE;

    if (SvTRUE(ERRSV)) {
        MP_TRACE_h(MP_FUNC, "$@ = %s", SvPVX(ERRSV));
        status = HTTP_INTERNAL_SERVER_ERROR;
    }

    return status;
}

int modperl_run_handlers(int idx, request_rec *r, conn_rec *c,
                         server_rec *s, int type, ...)
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
    va_list args;
    AV *av_args = Nullav;

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
        PERL_SET_CONTEXT(aTHX);
    }
#endif

    MP_TRACE_h(MP_FUNC, "running %d %s handlers\n",
               av->nelts, desc);
    handlers = (modperl_handler_t **)av->elts;

    switch (type) {
      case MP_HANDLER_TYPE_DIR:
      case MP_HANDLER_TYPE_SRV:
        modperl_handler_make_args(aTHX_ &av_args,
                                  "Apache::RequestRec", r, NULL);
        break;
      case MP_HANDLER_TYPE_CONN:
        modperl_handler_make_args(aTHX_ &av_args,
                                  "Apache::Connection", c, NULL);
        break;
      case MP_HANDLER_TYPE_FILE:
          {
              apr_pool_t *pconf, *plog, *ptemp;

              va_start(args, type);
              pconf = va_arg(args, apr_pool_t *);
              plog  = va_arg(args, apr_pool_t *);
              ptemp = va_arg(args, apr_pool_t *);
              va_end(args);

              modperl_handler_make_args(aTHX_ &av_args,
                                        "Apache::Pool", pconf,
                                        "Apache::Pool", plog,
                                        "Apache::Pool", ptemp,
                                        "Apache::Server", s, NULL);
          }
          break;
      case MP_HANDLER_TYPE_PROC:
          {
              apr_pool_t *pconf;

              va_start(args, type);
              pconf = va_arg(args, apr_pool_t *);
              va_end(args);

              if (!p) {
                  p = pconf;
              }

              modperl_handler_make_args(aTHX_ &av_args,
                                        "Apache::Pool", pconf,
                                        "Apache::Server", s, NULL);
          }
          break;
    };

    for (i=0; i<av->nelts; i++) {
        if ((status = modperl_callback(aTHX_ handlers[i], p, av_args)) != OK) {
            status = modperl_errsv(aTHX_ status, r, s);
        }

        MP_TRACE_h(MP_FUNC, "%s returned %d\n",
                   handlers[i]->name, status);
    }

    SvREFCNT_dec((SV*)av_args);

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
    modperl_run_handlers(idx, NULL, NULL, s, MP_HANDLER_TYPE_PROC, p);
}

void modperl_files_callback(int idx,
                            apr_pool_t *pconf, apr_pool_t *plog,
                            apr_pool_t *ptemp, server_rec *s)
{
    modperl_run_handlers(idx, NULL, NULL, s, MP_HANDLER_TYPE_FILE,
                         pconf, plog, ptemp);
}
