#include "mod_perl.h"

void modperl_startup(server_rec *s, ap_pool_t *p)
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

    if (!(perl = perl_alloc())) {
        perror("perl_alloc");
        exit(1);
    }

    perl_construct(perl);

    argv = modperl_srv_config_argv_init(scfg, &argc);

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

    modperl_interp_init(s, p, perl);
}

void modperl_init(server_rec *s, ap_pool_t *p)
{
    modperl_startup(s, p);
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
    ap_hook_open_logs(modperl_hook_init, NULL, NULL, HOOK_MIDDLE);
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
#endif
    MP_CMD_POST_READ_REQUEST_ENTRY,
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
