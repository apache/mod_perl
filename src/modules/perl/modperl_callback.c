/* Copyright 2000-2004 The Apache Software Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
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

int modperl_callback(pTHX_ modperl_handler_t *handler, apr_pool_t *p,
                     request_rec *r, server_rec *s, AV *args)
{
    CV *cv = Nullcv;
    I32 flags = G_EVAL|G_SCALAR;
    dSP;
    int count, status = OK;
    int tainted_orig = PL_tainted;

    /* handler callbacks shouldn't affect each other's taintedness
     * state, so start every callback with a clear record and restore
     * at the end. one of the main problems we are trying to solve is
     * that when modperl_croak called (which calls perl's
     * croak(Nullch) to throw an error object) it leaves the
     * interprter in the tainted state (which supposedly will be fixed
     * in 5.8.6) which later affects other callbacks that call eval,
     * etc, which triggers perl crash with:
     * Insecure dependency in eval while running setgid.
     * Callback called exit.
     */
    PL_tainted = TAINT_NOT;
    
    if ((status = modperl_handler_resolve(aTHX_ &handler, p, s)) != OK) {
        PL_tainted = tainted_orig;
        return status;
    }

    ENTER;SAVETMPS;
    PUSHMARK(SP);

    if (MpHandlerMETHOD(handler)) {
        GV *gv;
        if (!handler->mgv_obj) {
            Perl_croak(aTHX_ "panic: %s method handler object is NULL!",
                       handler->name);
        }
        gv = modperl_mgv_lookup(aTHX_ handler->mgv_obj);
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
#ifdef USE_ITHREADS
        /* it's possible that the interpreter that is running the anon
         * cv, isn't the one that compiled it. so to be safe need to
         * re-eval the deparsed form before using it.
         * XXX: possible optimizations, see modperl_handler_new_anon */
        SV *sv = eval_pv(handler->name, TRUE); 
        cv = (CV*)SvRV(sv);
#else
        /* the same interpreter that has compiled the anon cv is used
         * to run it */
        if (!handler->cv) {
            SV *sv = eval_pv(handler->name, TRUE); 
            handler->cv = (CV*)SvRV(sv); /* cache */
        }
        cv = handler->cv;
#endif
    }
    else {
        GV *gv = modperl_mgv_lookup_autoload(aTHX_ handler->mgv_cv, s, p);
        if (gv) {
            cv = modperl_mgv_cv(gv);
        }
        else {
            
            const char *name;
            modperl_mgv_t *symbol = handler->mgv_cv;
            
             /* XXX: need to validate *symbol */
            if (symbol && symbol->name) {
                name = modperl_mgv_as_string(aTHX_ symbol, p, 0);
            }
            else {
                name = handler->name;
            }
            
            MP_TRACE_h(MP_FUNC, "[%s %s] lookup of %s failed\n",
                       modperl_pid_tid(p),
                       modperl_server_desc(s, p), name);
            ap_log_error(APLOG_MARK, APLOG_ERR, 0, s,
                         "lookup of '%s' failed", name);
            status = HTTP_INTERNAL_SERVER_ERROR;
        }
    }

    if (status == OK) {
        count = call_sv((SV*)cv, flags);

        SPAGAIN;

        if (count != 1) {
            /* XXX can this really happen with G_EVAL|G_SCALAR? */
            status = OK;
        }
        else {
            SV *status_sv = POPs;

            if (status_sv == &PL_sv_undef) {
                /* ModPerl::Util::exit() and Perl_croak internally
                 * arrange to return PL_sv_undef with G_EVAL|G_SCALAR */
                status = OK; 
            }
            else {
                status = SvIVx(status_sv);
            }
        }

        PUTBACK;
    }
    
    FREETMPS;LEAVE;

    if (SvTRUE(ERRSV)) {
        MP_TRACE_h(MP_FUNC, "$@ = %s", SvPV_nolen(ERRSV));
        status = HTTP_INTERNAL_SERVER_ERROR;
    }

    if (status == HTTP_INTERNAL_SERVER_ERROR) {
        if (r && r->notes) {
            apr_table_set(r->notes, "error-notes", SvPV_nolen(ERRSV));
        }
    }

    PL_tainted = tainted_orig;

    return status;
}

int modperl_callback_run_handlers(int idx, int type,
                                  request_rec *r, conn_rec *c,
                                  server_rec *s,
                                  apr_pool_t *pconf,
                                  apr_pool_t *plog,
                                  apr_pool_t *ptemp,
                                  modperl_hook_run_mode_e run_mode)
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
        MP_TRACE_h(MP_FUNC, "PerlOff for server %s:%u\n",
                   s->server_hostname, s->port);
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

    /* XXX: would like to do this in modperl_hook_create_request()
     * but modperl_interp_select() is what figures out if
     * PerlInterpScope eq handler, in which case we do not register
     * a cleanup.  modperl_hook_create_request() is also currently always
     * run even if modperl isn't handling any part of the request
     */
    modperl_config_req_cleanup_register(r, rcfg);

    switch (type) {
      case MP_HANDLER_TYPE_PER_SRV:
        modperl_handler_make_args(aTHX_ &av_args,
                                  "Apache::RequestRec", r, NULL);

        /* per-server PerlSetEnv and PerlPassEnv - only once per-request */
        if (! MpReqPERL_SET_ENV_SRV(rcfg)) {
            modperl_env_configure_request_srv(aTHX_ r);
        }

        break;
      case MP_HANDLER_TYPE_PER_DIR:
        modperl_handler_make_args(aTHX_ &av_args,
                                  "Apache::RequestRec", r, NULL);

        /* per-directory PerlSetEnv - only once per-request */
        if (! MpReqPERL_SET_ENV_DIR(rcfg)) {
            modperl_env_configure_request_dir(aTHX_ r);
        }

        break;
      case MP_HANDLER_TYPE_PRE_CONNECTION:
      case MP_HANDLER_TYPE_CONNECTION:
        modperl_handler_make_args(aTHX_ &av_args,
                                  "Apache::Connection", c, NULL);
        break;
      case MP_HANDLER_TYPE_FILES:
        modperl_handler_make_args(aTHX_ &av_args,
                                  "Apache::Pool", pconf,
                                  "Apache::Pool", plog,
                                  "Apache::Pool", ptemp,
                                  "Apache::ServerRec", s, NULL);
        break;
      case MP_HANDLER_TYPE_PROCESS:
        modperl_handler_make_args(aTHX_ &av_args,
                                  "Apache::Pool", pconf,
                                  "Apache::ServerRec", s, NULL);
        break;
    };

    modperl_callback_current_callback_set(desc);
    
    MP_TRACE_h(MP_FUNC, "[%s] running %d %s handlers\n",
               modperl_pid_tid(p), av->nelts, desc);
    handlers = (modperl_handler_t **)av->elts;

    for (i=0; i<av->nelts; i++) {
        status = modperl_callback(aTHX_ handlers[i], p, r, s, av_args);
        
        MP_TRACE_h(MP_FUNC, "%s returned %d\n",
                   handlers[i]->name, status);

        /* follow Apache's lead and let OK terminate the phase for
         * MP_HOOK_RUN_FIRST handlers.  MP_HOOK_RUN_ALL handlers keep
         * going on OK.  MP_HOOK_VOID handlers ignore all errors.
         */

        if (run_mode == MP_HOOK_RUN_ALL) {
            /* the normal case:
             *   OK and DECLINED continue 
             *   errors end the phase
             */
            if ((status != OK) && (status != DECLINED)) {

                status = modperl_errsv(aTHX_ status, r, s);
#ifdef MP_TRACE
                if (i+1 != av->nelts) {
                    MP_TRACE_h(MP_FUNC, "error status %d leaves %d "
                               "uncalled handlers\n",
                               status, desc, av->nelts-i-1);
                }
#endif
                break;
            }
        }
        else if (run_mode == MP_HOOK_RUN_FIRST) {
            /* the exceptional case:
             *   OK and errors end the phase
             *   DECLINED continues
             */

            if (status == OK) {
#ifdef MP_TRACE
                if (i+1 != av->nelts) {
                    MP_TRACE_h(MP_FUNC, "OK ends the %s stack, "
                               "leaving %d uncalled handlers\n",
                               desc, av->nelts-i-1);
                }
#endif
                break;
            }
            if (status != DECLINED) {
                status = modperl_errsv(aTHX_ status, r, s);
#ifdef MP_TRACE
                if (i+1 != av->nelts) {
                    MP_TRACE_h(MP_FUNC, "error status %d leaves %d "
                               "uncalled handlers\n",
                               status, desc, av->nelts-i-1);
                }
#endif
                break;
            }
        }
        else {
            /* the rare case.
             * MP_HOOK_VOID handlers completely ignore the return status
             * Apache should handle whatever mod_perl returns, 
             * so there is no need to mess with the status
             */
        }

        /* it's possible that during the last callback a new handler
         * was pushed onto the same phase it's running from. av needs
         * to be updated.
         *
         * XXX: would be nice to somehow optimize that
         */
        avp = modperl_handler_lookup_handlers(dcfg, scfg, rcfg, p,
                                              type, idx, FALSE, NULL);
        if (avp && (av = *avp)) {
            handlers = (modperl_handler_t **)av->elts;
        }
    }

    SvREFCNT_dec((SV*)av_args);

    /* PerlInterpScope handler */
    MP_INTERP_PUTBACK(interp);

    return status;
}

int modperl_callback_per_dir(int idx, request_rec *r,
                             modperl_hook_run_mode_e run_mode)
{
    return modperl_callback_run_handlers(idx, MP_HANDLER_TYPE_PER_DIR,
                                         r, NULL, r->server,
                                         NULL, NULL, NULL, run_mode);
}

int modperl_callback_per_srv(int idx, request_rec *r, 
                             modperl_hook_run_mode_e run_mode)
{
    return modperl_callback_run_handlers(idx,
                                         MP_HANDLER_TYPE_PER_SRV,
                                         r, NULL, r->server,
                                         NULL, NULL, NULL, run_mode);
}

int modperl_callback_connection(int idx, conn_rec *c, 
                                modperl_hook_run_mode_e run_mode)
{
    return modperl_callback_run_handlers(idx,
                                         MP_HANDLER_TYPE_CONNECTION,
                                         NULL, c, c->base_server,
                                         NULL, NULL, NULL, run_mode);
}

int modperl_callback_pre_connection(int idx, conn_rec *c, void *csd,
                                    modperl_hook_run_mode_e run_mode)
{
    return modperl_callback_run_handlers(idx,
                                         MP_HANDLER_TYPE_PRE_CONNECTION,
                                         NULL, c, c->base_server,
                                         NULL, NULL, NULL, run_mode);
}

void modperl_callback_process(int idx, apr_pool_t *p, server_rec *s,
                              modperl_hook_run_mode_e run_mode)
{
    modperl_callback_run_handlers(idx, MP_HANDLER_TYPE_PROCESS,
                                  NULL, NULL, s,
                                  p, NULL, NULL, run_mode);
}

int modperl_callback_files(int idx,
                           apr_pool_t *pconf, apr_pool_t *plog,
                           apr_pool_t *ptemp, server_rec *s,
                           modperl_hook_run_mode_e run_mode)
{
    return modperl_callback_run_handlers(idx, MP_HANDLER_TYPE_FILES,
                                         NULL, NULL, s,
                                         pconf, plog, ptemp, run_mode);
}
