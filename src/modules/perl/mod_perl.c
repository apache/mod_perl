#include "mod_perl.h"

PerlInterpreter *modperl_startup(server_rec *s, apr_pool_t *p)
{
    MP_dSCFG(s);
    PerlInterpreter *perl;
    int status;
    char **argv;
    int argc;

#ifdef MP_USE_GTOP
    MP_TRACE_m_do(
        scfg->gtop = modperl_gtop_new(p);
        modperl_gtop_do_proc_mem_before(MP_FUNC ": perl_parse");
    );
#endif

    argv = modperl_srv_config_argv_init(scfg, &argc);

    if (!(perl = perl_alloc())) {
        perror("perl_alloc");
        exit(1);
    }

    perl_construct(perl);

    status = perl_parse(perl, xs_init, argc, argv, NULL);

    if (status) {
        perror("perl_parse");
        exit(1);
    }

    perl_run(perl);

#ifdef MP_USE_GTOP
    MP_TRACE_m_do(
        modperl_gtop_do_proc_mem_after(MP_FUNC ": perl_parse");
    );
#endif

    return perl;
}

void modperl_init(server_rec *base_server, apr_pool_t *p)
{
    server_rec *s;
    modperl_srv_config_t *base_scfg =
      (modperl_srv_config_t *)
        ap_get_module_config(base_server->module_config, &perl_module);
    PerlInterpreter *base_perl;

    MP_TRACE_d_do(MpSrv_dump_flags(base_scfg,
                                   base_server->server_hostname));

    if (!MpSrvENABLED(base_scfg)) {
        /* how silly */
        return;
    }

    base_perl = modperl_startup(base_server, p);

#ifdef USE_ITHREADS
    modperl_interp_init(base_server, p, base_perl);
    MpInterpBASE_On(base_scfg->mip->parent);
#endif

    for (s=base_server->next; s; s=s->next) {
        MP_dSCFG(s);
        PerlInterpreter *perl = base_perl;

        MP_TRACE_d_do(MpSrv_dump_flags(scfg, s->server_hostname));

        /* if alloc flags is On, virtual host gets its own parent perl */
        if (MpSrvPARENT(scfg)) {
            perl = modperl_startup(s, p);
            MP_TRACE_i(MP_FUNC, "modperl_startup() server=%s\n",
                       s->server_hostname);
        }

#ifdef USE_ITHREADS

        if (!MpSrvENABLED(scfg)) {
            scfg->mip = NULL;
            continue;
        }

        /* if alloc flags is On or clone flag is On,
         *  virtual host gets its own mip
         */
        if (MpSrvPARENT(scfg) || MpSrvCLONE(scfg)) {
            MP_TRACE_i(MP_FUNC, "modperl_interp_init() server=%s\n",
                       s->server_hostname);
            modperl_interp_init(s, p, perl);
        }

        /* if we allocated a parent perl, mark it to be destroyed */
        if (MpSrvPARENT(scfg)) {
            MpInterpBASE_On(scfg->mip->parent);
        }

        if (!scfg->mip) {
            /* since mips are created after merge_server_configs()
             * need to point to the base mip here if this vhost
             * doesn't have its own
             */
            scfg->mip = base_scfg->mip;
        }

#endif /* USE_ITHREADS */

    }
}

void modperl_hook_init(apr_pool_t *pconf, apr_pool_t *plog, 
                       apr_pool_t *ptemp, server_rec *s)
{
    modperl_init(s, pconf);
}

void modperl_pre_config_handler(apr_pool_t *p, apr_pool_t *plog,
                                apr_pool_t *ptemp)
{
    /* XXX: htf can we have PerlPreConfigHandler
     * without first configuring mod_perl ?
     */
}

static void modperl_hook_post_config(apr_pool_t *pconf, apr_pool_t *plog,
                                     apr_pool_t *ptemp, server_rec *s)
{
#ifdef USE_ITHREADS
    MP_dSCFG(s);
    dTHXa(scfg->mip->parent->perl);
#endif
    ap_add_version_component(pconf, MP_VERSION_STRING);
    ap_add_version_component(pconf,
                             Perl_form(aTHX_ "Perl/v%vd", PL_patchlevel));
}

void modperl_register_hooks(void)
{
    ap_hook_open_logs(modperl_hook_init, NULL, NULL, AP_HOOK_MIDDLE);

    ap_hook_handler(modperl_response_handler, NULL, NULL, AP_HOOK_MIDDLE);

    ap_hook_insert_filter(modperl_output_filter_register,
                          NULL, NULL, AP_HOOK_LAST);

    ap_register_output_filter(MODPERL_OUTPUT_FILTER_NAME,
                              modperl_output_filter_handler,
                              AP_FTYPE_CONTENT);

    ap_hook_post_config(modperl_hook_post_config, NULL, NULL, AP_HOOK_MIDDLE);

    modperl_register_handler_hooks();
}

static const command_rec modperl_cmds[] = {  
    MP_SRV_CMD_ITERATE("PerlSwitches", switches, "Perl Switches"),
    MP_SRV_CMD_ITERATE("PerlOptions", options, "Perl Options"),
#ifdef MP_TRACE
    MP_SRV_CMD_TAKE1("PerlTrace", trace, "Trace level"),
#endif
#ifdef USE_ITHREADS
    MP_SRV_CMD_TAKE1("PerlInterpStart", interp_start,
                     "Number of Perl interpreters to start"),
    MP_SRV_CMD_TAKE1("PerlInterpMax", interp_max,
                     "Max number of running Perl interpreters"),
    MP_SRV_CMD_TAKE1("PerlInterpMaxSpare", interp_max_spare,
                     "Max number of spare Perl interpreters"),
    MP_SRV_CMD_TAKE1("PerlInterpMinSpare", interp_min_spare,
                     "Min number of spare Perl interpreters"),
    MP_SRV_CMD_TAKE1("PerlInterpMaxRequests", interp_max_requests,
                     "Max number of requests per Perl interpreters"),
#endif
    MP_CMD_ENTRIES,
    { NULL }, 
}; 

void modperl_response_init(request_rec *r)
{
    MP_dRCFG;

    modperl_request_config_init(r, rcfg);

    /* setup buffer for output */
    rcfg->wbucket.pool = r->pool;
    rcfg->wbucket.filters = r->output_filters;
    rcfg->wbucket.outcnt = 0;
}

void modperl_response_finish(request_rec *r)
{
    MP_dRCFG;

    /* flush output buffer */
    modperl_wbucket_flush(&rcfg->wbucket);
}

int modperl_response_handler(request_rec *r)
{
    int retval;

    if (!strEQ(r->handler, "modperl")) {
        return DECLINED;
    }

    modperl_response_init(r);

    retval = modperl_per_dir_callback(MP_RESPONSE_HANDLER, r);

    if ((retval == DECLINED) && r->content_type) {
        r->handler = r->content_type; /* let http_core or whatever try */
    }

    modperl_response_finish(r);

    return retval;
}

module MODULE_VAR_EXPORT perl_module = {
    STANDARD20_MODULE_STUFF, 
    modperl_create_dir_config, /* dir config creater */
    modperl_merge_dir_config,  /* dir merger --- default is to override */
    modperl_create_srv_config, /* server config */
    modperl_merge_srv_config,  /* merge server config */
    modperl_cmds,              /* table of config file commands       */
    modperl_register_hooks,    /* register hooks */
};
