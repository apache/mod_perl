#include "mod_perl.h"

void *modperl_create_dir_config(ap_pool_t *p, char *dir)
{
    return NULL;
}

void *modperl_merge_dir_config(ap_pool_t *p, void *base, void *add)
{
    return NULL;
}

modperl_srv_config_t *modperl_srv_config_new(ap_pool_t *p)
{
    return (modperl_srv_config_t *)
        ap_pcalloc(p, sizeof(modperl_srv_config_t));
}

void *modperl_create_srv_config(ap_pool_t *p, server_rec *s)
{
    modperl_srv_config_t *scfg = modperl_srv_config_new(p);

    return scfg;
}

void *modperl_merge_srv_config(ap_pool_t *p, void *basev, void *addv)
{
    modperl_srv_config_t
        *base = (modperl_srv_config_t *)basev,
        *add  = (modperl_srv_config_t *)addv,
        *mrg  = modperl_srv_config_new(p);

    mrg->mip = add->mip ? add->mip : base->mip;

    return mrg;
}
