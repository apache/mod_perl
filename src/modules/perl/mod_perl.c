#include "mod_perl.h"

void modperl_startup(server_rec *s, ap_pool_t *p)
{
    PerlInterpreter *perl;
    int status;
    char *argv[] = { "httpd", "/dev/null" };
    int argc = 2;

    if (!(perl = perl_alloc())) {
        perror("perl_alloc");
        exit(1);
    }

    perl_construct(perl);
    
    status = perl_parse(perl, NULL, argc, argv, NULL);

    if (status) {
        perror("perl_parse");
        exit(1);
    }

    perl_run(perl);

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
