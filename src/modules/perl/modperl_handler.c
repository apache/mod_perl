#include "mod_perl.h"

modperl_handler_t *modperl_handler_new(apr_pool_t *p, const char *name)
{
    modperl_handler_t *handler = 
        (modperl_handler_t *)apr_pcalloc(p, sizeof(*handler));

    handler->name = name;
    MP_TRACE_h(MP_FUNC, "new handler %s\n", handler->name);

    return handler;
}

int modperl_handler_resolve(pTHX_ modperl_handler_t **handp,
                            apr_pool_t *p, server_rec *s)
{
    int duped=0;
    modperl_handler_t *handler = *handp;

#ifdef USE_ITHREADS
    if (p && !MpHandlerPARSED(handler) && !MpHandlerDYNAMIC(handler)) {
        MP_dSCFG(s);
        if (scfg->threaded_mpm) {
            /*
             * cannot update the handler structure at request time without
             * locking, so just copy it
             */
            handler = *handp = modperl_handler_dup(p, handler);
            duped = 1;
        }
    }
#endif

    MP_TRACE_h_do(MpHandler_dump_flags(handler, handler->name));

    if (!MpHandlerPARSED(handler)) {
        apr_pool_t *rp = duped ? p : s->process->pconf;
        MpHandlerAUTOLOAD_On(handler);

        MP_TRACE_h(MP_FUNC,
                   "handler %s was not compiled at startup, "
                   "attempting to resolve using %s pool 0x%lx\n",
                   handler->name,
                   duped ? "current" : "server conf",
                   (unsigned long)rp);

        if (!modperl_mgv_resolve(aTHX_ handler, rp, handler->name)) {
            ap_log_error(APLOG_MARK, APLOG_ERR, 0, s, 
                         "failed to resolve handler `%s'",
                         handler->name);
            return HTTP_INTERNAL_SERVER_ERROR;
        }
    }

    return OK;
}

modperl_handler_t *modperl_handler_dup(apr_pool_t *p,
                                       modperl_handler_t *h)
{
    MP_TRACE_h(MP_FUNC, "dup handler %s\n", h->name);
    return modperl_handler_new(p, h->name);
}

int modperl_handler_equal(modperl_handler_t *h1, modperl_handler_t *h2)
{
    if (h1->mgv_cv && h2->mgv_cv) {
        return modperl_mgv_equal(h1->mgv_cv, h2->mgv_cv);
    }
    return strEQ(h1->name, h2->name);
}

MpAV *modperl_handler_array_merge(apr_pool_t *p, MpAV *base_a, MpAV *add_a)
{
    int i, j;
    modperl_handler_t **base_h, **add_h, **mrg_h;
    MpAV *mrg_a;

    if (!add_a) {
        return base_a;
    }

    if (!base_a) {
        return add_a;
    }

    mrg_a = apr_array_copy(p, base_a);

    mrg_h  = (modperl_handler_t **)mrg_a->elts;
    base_h = (modperl_handler_t **)base_a->elts;
    add_h  = (modperl_handler_t **)add_a->elts;

    for (i=0; i<base_a->nelts; i++) {
        for (j=0; j<add_a->nelts; j++) {
            if (modperl_handler_equal(base_h[i], add_h[j])) {
                MP_TRACE_d(MP_FUNC, "both base and new config contain %s\n",
                           add_h[j]->name);
            }
            else {
                modperl_handler_array_push(mrg_a, add_h[j]);
                MP_TRACE_d(MP_FUNC, "base does not contain %s\n",
                           add_h[j]->name);
            }
        }
    }

    return mrg_a;
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

#define set_desc(dtype) \
    MP_TRACE_a_do(if (desc) *desc = modperl_handler_desc_##dtype(idx))

#define check_modify(dtype) \
if ((action > MP_HANDLER_ACTION_GET) && rcfg) { \
    dTHX; \
    Perl_croak(aTHX_ "too late to modify %s handlers", \
               modperl_handler_desc_##dtype(idx)); \
}

/*
 * generic function to lookup handlers for use in modperl_callback(),
 * $r->{push,set,get}_handlers, $s->{push,set,get}_handlers
 * $s->push/set at startup time are the same as configuring Perl*Handlers
 * $r->push/set at request time will create entries in r->request_config
 * push will first merge with configured handlers, unless an entry
 * in r->request_config already exists.  in this case, push or set has
 * already been called for the given handler, 
 * r->request_config entries then override those in r->per_dir_config
 */

MpAV **modperl_handler_lookup_handlers(modperl_config_dir_t *dcfg,
                                       modperl_config_srv_t *scfg,
                                       modperl_config_req_t *rcfg,
                                       apr_pool_t *p,
                                       int type, int idx,
                                       modperl_handler_action_e action,
                                       const char **desc)
{
    MpAV **avp = NULL, **ravp = NULL;

    switch (type) {
      case MP_HANDLER_TYPE_PER_DIR:
        avp = &dcfg->handlers_per_dir[idx];
        if (rcfg) {
            ravp = &rcfg->handlers_per_dir[idx];
        }
        set_desc(per_dir);
        break;
      case MP_HANDLER_TYPE_PER_SRV:
        avp = &scfg->handlers_per_srv[idx];
        if (rcfg) {
            ravp = &rcfg->handlers_per_srv[idx];
        }
        set_desc(per_srv);
        break;
      case MP_HANDLER_TYPE_CONNECTION:
        avp = &scfg->handlers_connection[idx];
        check_modify(connection);
        set_desc(connection);
        break;
      case MP_HANDLER_TYPE_FILES:
        avp = &scfg->handlers_files[idx];
        check_modify(files);
        set_desc(files);
        break;
      case MP_HANDLER_TYPE_PROCESS:
        avp = &scfg->handlers_process[idx];
        check_modify(files);
        set_desc(process);
        break;
    };

    if (!avp) {
        /* should never happen */
        fprintf(stderr, "PANIC: no such handler type: %d\n", type);
        return NULL;
    }

    switch (action) {
      case MP_HANDLER_ACTION_GET:
        /* just a lookup */
        break;
      case MP_HANDLER_ACTION_PUSH:
        if (ravp && !*ravp) {
            if (*avp) {
                /* merge with existing configured handlers */
                *ravp = apr_array_copy(p, *avp);
            }
            else {
                /* no request handlers have been previously pushed or set */
                *ravp = modperl_handler_array_new(p);
            }
        }
        else if (!*avp) {
            /* directly modify the configuration at startup time */
            *avp = modperl_handler_array_new(p);
        }
        break;
      case MP_HANDLER_ACTION_SET:
        if (ravp) {
            if (*ravp) {
                /* wipe out existing pushed/set request handlers */
                (*ravp)->nelts = 0;
            }
            else {
                /* no request handlers have been previously pushed or set */
                *ravp = modperl_handler_array_new(p);
            }
        }
        else if (*avp) {
            /* wipe out existing configuration, only at startup time */
            (*avp)->nelts = 0;
        }
        else {
            /* no configured handlers for this phase */
            *avp = modperl_handler_array_new(p);
        }
        break;
    }

    return (ravp && *ravp) ? ravp : avp;
}

MpAV **modperl_handler_get_handlers(request_rec *r, conn_rec *c, server_rec *s,
                                    apr_pool_t *p, const char *name,
                                    modperl_handler_action_e action)
{
    MP_dSCFG(s);
    MP_dDCFG;
    MP_dRCFG;

    int idx, type;

    if (!r) {
        /* so $s->{push,set}_handlers can configured request-time handlers */
        dcfg = modperl_config_dir_get_defaults(s);
    }

    if ((idx = modperl_handler_lookup(name, &type)) == DECLINED) {
        return FALSE;
    }

    return modperl_handler_lookup_handlers(dcfg, scfg, rcfg, p,
                                           type, idx,
                                           action, NULL);
}

int modperl_handler_push_handlers(pTHX_ apr_pool_t *p,
                                  MpAV *handlers, SV *sv)
{
    char *handler_name;

    if ((handler_name = modperl_mgv_name_from_sv(aTHX_ p, sv))) {
        modperl_handler_t *handler =
            modperl_handler_new(p, apr_pstrdup(p, handler_name));
        modperl_handler_array_push(handlers, handler);
        return TRUE;
    }

    MP_TRACE_h(MP_FUNC, "unable to push_handler 0x%lx\n",
               (unsigned long)sv);

    return FALSE;
}

/* convert array header of modperl_handlers_t's to AV ref of CV refs */
SV *modperl_handler_perl_get_handlers(pTHX_ MpAV **handp, apr_pool_t *p)
{
    AV *av = newAV();
    int i;
    modperl_handler_t **handlers;

    if (!(handp && *handp)) {
        return &PL_sv_undef;
    }

    av_extend(av, (*handp)->nelts - 1);

    handlers = (modperl_handler_t **)(*handp)->elts;

    for (i=0; i<(*handp)->nelts; i++) {
        modperl_handler_t *handler = NULL;
        GV *gv;

        if (MpHandlerPARSED(handlers[i])) {
            handler = handlers[i];
        }
        else {
#ifdef USE_ITHREADS
            if (!MpHandlerDYNAMIC(handlers[i])) {
                handler = modperl_handler_dup(p, handlers[i]);
            }
#endif
            if (!handler) {
                handler = handlers[i];
            }

            if (!modperl_mgv_resolve(aTHX_ handler, p, handler->name)) {
                MP_TRACE_h(MP_FUNC, "failed to resolve handler %s\n",
                           handler->name);
            }

        }

        if (handler->mgv_cv) {
            if ((gv = modperl_mgv_lookup(aTHX_ handler->mgv_cv))) {
                CV *cv = modperl_mgv_cv(gv);
                av_push(av, newRV_inc((SV*)cv));
            }
        }
        else {
            av_push(av, newSVpv(handler->name, 0));
        }
    }

    return newRV_noinc((SV*)av);
}

#define push_sv_handler \
    if ((modperl_handler_push_handlers(aTHX_ p, *handlers, sv))) { \
        MpHandlerDYNAMIC_On(modperl_handler_array_last(*handlers)); \
    }

/* allow push/set of single cv ref or array ref of cv refs */
int modperl_handler_perl_add_handlers(pTHX_
                                      request_rec *r,
                                      conn_rec *c,
                                      server_rec *s,
                                      apr_pool_t *p,
                                      const char *name,
                                      SV *sv,
                                      modperl_handler_action_e action)
{
    I32 i;
    AV *av = Nullav;
    MpAV **handlers =
        modperl_handler_get_handlers(r, c, s,
                                     p, name, action);

    if (!(handlers && *handlers)) {
        return FALSE;
    }

    if (SvROK(sv) && (SvTYPE(SvRV(sv)) == SVt_PVAV)) {
        av = (AV*)SvRV(sv);

        for (i=0; i <= AvFILL(av); i++) {
            sv = *av_fetch(av, i, FALSE);
            push_sv_handler;
        }
    }
    else {
        push_sv_handler;
    }

    return TRUE;
}
