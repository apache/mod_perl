#include "mod_perl.h"

PerlInterpreter *modperl_startup(server_rec *s, ap_pool_t *p)
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

void modperl_init(server_rec *s, ap_pool_t *p)
{
    server_rec *base_server = s;
    server_rec *srvp;
    PerlInterpreter *base_perl = modperl_startup(base_server, p);
    modperl_interp_init(base_server, p, base_perl);

    {
        MP_dSCFG(base_server);
        MpInterpBASE_On(scfg->mip->parent);
    }

    for (srvp=base_server->next; srvp; srvp=srvp->next) {
        MP_dSCFG(srvp);
        PerlInterpreter *perl = base_perl;

        if (1) {
            /* XXX: using getenv() just for testing here */
            char *do_alloc = getenv("MP_SRV_ALLOC_TEST");
            char *do_clone = getenv("MP_SRV_CLONE_TEST");
            if (do_alloc && strEQ(do_alloc, srvp->server_hostname)) {
                MpSrvPERL_ALLOC_On(scfg);
            }
            if (do_clone && strEQ(do_clone, srvp->server_hostname)) {
                MpSrvPERL_CLONE_On(scfg);
            }
        }

        /* if alloc flags is On, virtual host gets its own parent perl */
        if (MpSrvPERL_ALLOC(scfg)) {
            perl = modperl_startup(srvp, p);
            MP_TRACE_i(MP_FUNC, "modperl_startup() server=%s\n",
                       srvp->server_hostname);
        }

#ifdef USE_ITHREADS
        /* if alloc flags is On or clone flag is On,
         *  virtual host gets its own mip
         */
        if (MpSrvPERL_ALLOC(scfg) || MpSrvPERL_CLONE(scfg)) {
            MP_TRACE_i(MP_FUNC, "modperl_interp_init() server=%s\n",
                       srvp->server_hostname);
            modperl_interp_init(srvp, p, perl);
        }

        /* if we allocated a parent perl, mark it to be destroyed */
        if (MpSrvPERL_ALLOC(scfg)) {
            MpInterpBASE_On(scfg->mip->parent);
        }
#endif
    }
}

void modperl_hook_init(ap_pool_t *pconf, ap_pool_t *plog, 
                       ap_pool_t *ptemp, server_rec *s)
{
    modperl_init(s, pconf);
}

void modperl_pre_config_handler(ap_pool_t *p, ap_pool_t *plog,
                                ap_pool_t *ptemp)
{
}

void modperl_register_hooks(void)
{
    /* XXX: should be pre_config hook or 1.xx logic */
    ap_hook_open_logs(modperl_hook_init, NULL, NULL, AP_HOOK_MIDDLE);
    modperl_register_handler_hooks();
}

static command_rec modperl_cmds[] = {  
    MP_SRV_CMD_ITERATE("PerlSwitches", switches, "Perl Switches"),
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

static handler_rec modperl_handlers[] = {
    { NULL },
};

module MODULE_VAR_EXPORT perl_module = {
    STANDARD20_MODULE_STUFF, 
    modperl_create_dir_config, /* dir config creater */
    modperl_merge_dir_config,  /* dir merger --- default is to override */
    modperl_create_srv_config, /* server config */
    modperl_merge_srv_config,  /* merge server config */
    modperl_cmds,              /* table of config file commands       */
    modperl_handlers,          /* handlers */
    modperl_register_hooks,    /* register hooks */
};
