#include "mod_perl.h"

void modperl_pre_config_handler(ap_context_t *p, ap_context_t *plog,
                                ap_context_t *ptemp)
{
}

void *modperl_create_dir_config(ap_context_t *p, char *dir)
{
    return NULL;
}

void *modperl_merge_dir_config(ap_context_t *p, void *base, void *add)
{
    return NULL;
}

void *modperl_create_srv_config(ap_context_t *p, server_rec *s)
{
    return NULL;
}

void *modperl_merge_srv_config(ap_context_t *p, void *base, void *add)
{
    return NULL;
}

void modperl_register_hooks(void)
{
}

static command_rec modperl_cmds[] = {  
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
